//
//  OCRManager.swift
//  TrayMe
//
//  OCR functionality using Vision framework for extracting text from images

import Foundation
import Vision
import AppKit

/// Manager for OCR operations
class OCRManager {
    
    /// Singleton instance
    static let shared = OCRManager()
    
    private init() {}
    
    /// Recognize text in an image
    /// - Parameters:
    ///   - image: The NSImage to process
    ///   - completion: Callback with recognized text or error
    func recognizeText(in image: NSImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion(.failure(OCRError.invalidImage))
            return
        }
        
        recognizeText(in: cgImage, completion: completion)
    }
    
    /// Recognize text in a CGImage
    /// - Parameters:
    ///   - cgImage: The CGImage to process
    ///   - completion: Callback with recognized text or error
    func recognizeText(in cgImage: CGImage, completion: @escaping (Result<String, Error>) -> Void) {
        // Create text recognition request
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(.failure(OCRError.noTextFound))
                return
            }
            
            // Extract recognized text
            let recognizedStrings = observations.compactMap { observation -> String? in
                observation.topCandidates(1).first?.string
            }
            
            if recognizedStrings.isEmpty {
                completion(.failure(OCRError.noTextFound))
            } else {
                let fullText = recognizedStrings.joined(separator: "\n")
                completion(.success(fullText))
            }
        }
        
        // Configure request
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US", "en-GB", "de-DE", "fr-FR", "es-ES", "it-IT", "pt-BR", "zh-Hans", "zh-Hant", "ja-JP", "ko-KR"]
        
        // Process on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Recognize text from image data
    /// - Parameters:
    ///   - data: Image data
    ///   - completion: Callback with recognized text or error
    func recognizeText(from data: Data, completion: @escaping (Result<String, Error>) -> Void) {
        guard let image = NSImage(data: data) else {
            completion(.failure(OCRError.invalidImage))
            return
        }
        recognizeText(in: image, completion: completion)
    }
    
    /// Recognize text from clipboard image
    /// - Parameter completion: Callback with recognized text or error
    func recognizeTextFromClipboard(completion: @escaping (Result<String, Error>) -> Void) {
        let pasteboard = NSPasteboard.general
        
        // Check for image data
        if let imageData = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png) {
            recognizeText(from: imageData, completion: completion)
        } else if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            recognizeText(in: image, completion: completion)
        } else {
            completion(.failure(OCRError.noImageInClipboard))
        }
    }
    
    /// Check if clipboard contains an image
    var hasImageInClipboard: Bool {
        let pasteboard = NSPasteboard.general
        return pasteboard.data(forType: .tiff) != nil ||
               pasteboard.data(forType: .png) != nil ||
               pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.isEmpty == false
    }
}

/// OCR errors
enum OCRError: LocalizedError {
    case invalidImage
    case noTextFound
    case noImageInClipboard
    case processingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format"
        case .noTextFound:
            return "No text found in image"
        case .noImageInClipboard:
            return "No image in clipboard"
        case .processingFailed:
            return "OCR processing failed"
        }
    }
}

/// Result of OCR processing
struct OCRResult {
    let text: String
    let confidence: Float
    let boundingBoxes: [CGRect]
}
