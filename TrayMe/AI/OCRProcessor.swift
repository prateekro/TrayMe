//
//  OCRProcessor.swift
//  TrayMe
//
//  OCR processing for images using Vision framework

import Foundation
import Vision
import AppKit
import CryptoKit

/// OCR processing result
struct OCRResult: Identifiable {
    let id = UUID()
    let text: String
    let confidence: Float
    let timestamp: Date
    let imageHash: String
}

/// Progress information for OCR processing
struct OCRProgress: Identifiable {
    let id = UUID()
    let imageHash: String
    let progress: Double
    let status: Status
    
    enum Status: String {
        case pending = "Pending"
        case processing = "Processing"
        case completed = "Completed"
        case failed = "Failed"
    }
}

/// OCR processor using Vision framework
@MainActor
class OCRProcessor: ObservableObject {
    /// Shared instance
    static let shared = OCRProcessor()
    
    /// Published OCR results cache
    @Published private(set) var results: [String: OCRResult] = [:]
    
    /// Current processing progress
    @Published private(set) var currentProgress: OCRProgress?
    
    /// Processing queue for background OCR
    private let processingQueue = DispatchQueue(label: "com.trayme.ocr", qos: .userInitiated)
    
    /// Maximum cache size
    private let maxCacheSize = 100
    
    /// Cache order for LRU eviction
    private var cacheOrder: [String] = []
    
    private init() {}
    
    // MARK: - Public API
    
    /// Process an image and extract text using OCR
    /// - Parameters:
    ///   - image: NSImage to process
    ///   - languages: Languages to recognize (nil for all)
    /// - Returns: OCR result with extracted text
    func processImage(_ image: NSImage, languages: [String]? = nil) async -> OCRResult? {
        // Calculate image hash for caching
        guard let imageHash = hashImage(image) else {
            return nil
        }
        
        // Check cache first
        if let cached = results[imageHash] {
            updateCacheOrder(imageHash)
            return cached
        }
        
        // Update progress
        currentProgress = OCRProgress(imageHash: imageHash, progress: 0.0, status: .processing)
        
        // Process in background
        return await withCheckedContinuation { continuation in
            processingQueue.async { [weak self] in
                let result = self?.performOCR(on: image, languages: languages, imageHash: imageHash)
                
                Task { @MainActor [weak self] in
                    if let result = result {
                        self?.cacheResult(result)
                        self?.currentProgress = OCRProgress(imageHash: imageHash, progress: 1.0, status: .completed)
                    } else {
                        self?.currentProgress = OCRProgress(imageHash: imageHash, progress: 1.0, status: .failed)
                    }
                    continuation.resume(returning: result)
                }
            }
        }
    }
    
    /// Process image data and extract text
    /// - Parameters:
    ///   - data: Image data (JPEG, PNG, etc.)
    ///   - languages: Languages to recognize
    /// - Returns: OCR result with extracted text
    func processImageData(_ data: Data, languages: [String]? = nil) async -> OCRResult? {
        guard let image = NSImage(data: data) else {
            return nil
        }
        return await processImage(image, languages: languages)
    }
    
    /// Process image from URL
    /// - Parameters:
    ///   - url: File URL of image
    ///   - languages: Languages to recognize
    /// - Returns: OCR result with extracted text
    func processImageURL(_ url: URL, languages: [String]? = nil) async -> OCRResult? {
        guard let image = NSImage(contentsOf: url) else {
            return nil
        }
        return await processImage(image, languages: languages)
    }
    
    /// Check if an image has cached OCR results
    func hasCachedResult(for image: NSImage) -> Bool {
        guard let hash = hashImage(image) else { return false }
        return results[hash] != nil
    }
    
    /// Clear OCR cache
    func clearCache() {
        results.removeAll()
        cacheOrder.removeAll()
    }
    
    /// Get cache size
    var cacheSize: Int {
        results.count
    }
    
    // MARK: - Private Methods
    
    /// Perform OCR using Vision framework
    private func performOCR(on image: NSImage, languages: [String]?, imageHash: String) -> OCRResult? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        if let languages = languages {
            request.recognitionLanguages = languages
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            
            guard let observations = request.results else {
                return nil
            }
            
            // Extract text and calculate average confidence
            var textLines: [String] = []
            var totalConfidence: Float = 0.0
            
            for observation in observations {
                if let candidate = observation.topCandidates(1).first {
                    textLines.append(candidate.string)
                    totalConfidence += candidate.confidence
                }
            }
            
            let fullText = textLines.joined(separator: "\n")
            let avgConfidence = observations.isEmpty ? 0.0 : totalConfidence / Float(observations.count)
            
            return OCRResult(
                text: fullText,
                confidence: avgConfidence,
                timestamp: Date(),
                imageHash: imageHash
            )
            
        } catch {
            print("OCR Error: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Calculate hash of image for caching
    private func hashImage(_ image: NSImage) -> String? {
        guard let tiffData = image.tiffRepresentation else {
            return nil
        }
        
        let hash = SHA256.hash(data: tiffData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Cache an OCR result
    private func cacheResult(_ result: OCRResult) {
        // Evict if at capacity
        if results.count >= maxCacheSize {
            if let oldestHash = cacheOrder.first {
                results.removeValue(forKey: oldestHash)
                cacheOrder.removeFirst()
            }
        }
        
        results[result.imageHash] = result
        cacheOrder.append(result.imageHash)
    }
    
    /// Update cache order for LRU tracking
    private func updateCacheOrder(_ hash: String) {
        cacheOrder.removeAll { $0 == hash }
        cacheOrder.append(hash)
    }
}

// MARK: - Supported Languages

extension OCRProcessor {
    /// Get list of supported recognition languages
    static var supportedLanguages: [String] {
        // Vision framework supports these languages
        [
            "en-US", "en-GB", "fr-FR", "de-DE", "it-IT", "pt-BR",
            "es-ES", "zh-Hans", "zh-Hant", "ja-JP", "ko-KR",
            "ru-RU", "uk-UA", "pl-PL", "nl-NL", "sv-SE"
        ]
    }
    
    /// Get display name for language code
    static func displayName(for languageCode: String) -> String {
        let locale = Locale(identifier: languageCode)
        return locale.localizedString(forIdentifier: languageCode) ?? languageCode
    }
}

// MARK: - Clipboard Image Detection

extension OCRProcessor {
    /// Check if clipboard contains an image
    static func clipboardContainsImage() -> Bool {
        let pasteboard = NSPasteboard.general
        return pasteboard.canReadItem(withDataConformingToTypes: [
            NSPasteboard.PasteboardType.png.rawValue,
            NSPasteboard.PasteboardType.tiff.rawValue,
            "public.jpeg"
        ])
    }
    
    /// Get image from clipboard
    static func getClipboardImage() -> NSImage? {
        let pasteboard = NSPasteboard.general
        
        // Try different image types
        if let data = pasteboard.data(forType: .png),
           let image = NSImage(data: data) {
            return image
        }
        
        if let data = pasteboard.data(forType: .tiff),
           let image = NSImage(data: data) {
            return image
        }
        
        // Try to read as file URL
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in urls {
                if let image = NSImage(contentsOf: url) {
                    return image
                }
            }
        }
        
        return nil
    }
}
