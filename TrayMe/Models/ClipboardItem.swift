//
//  ClipboardItem.swift
//  TrayMe
//

import Foundation
import AppKit

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    let content: String
    let timestamp: Date
    var isFavorite: Bool
    let type: ClipboardType
    
    // Image cache directory - uses Caches (cleaned by system when needed)
    private static let imageCacheDir: URL? = {
        guard let appSupport = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            print("❌ Could not access Caches directory")
            return nil
        }
        let cacheDir = appSupport.appendingPathComponent("TrayMe/ClipboardImages")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        return cacheDir
    }()
    
    init(content: String, type: ClipboardType = .text, isFavorite: Bool = false) {
        self.id = UUID()
        self.content = content
        self.timestamp = Date()
        self.isFavorite = isFavorite
        self.type = type
    }
    
    init(id: UUID, content: String, type: ClipboardType, date: Date, isFavorite: Bool) {
        self.id = id
        self.content = content
        self.timestamp = date
        self.isFavorite = isFavorite
        self.type = type
    }
    
    // Cache management methods
    private func imageCachePath() -> URL? {
        guard let cacheDir = Self.imageCacheDir else { return nil }
        return cacheDir.appendingPathComponent("\(id.uuidString).png")
    }
    
    func saveImage(_ image: NSImage) {
        guard let cachePath = imageCachePath(),
              let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return
        }
        try? pngData.write(to: cachePath, options: .atomic)
    }
    
    func loadImage() -> NSImage? {
        guard let cachePath = imageCachePath(),
              let data = try? Data(contentsOf: cachePath) else {
            return nil
        }
        return NSImage(data: data)
    }
    
    func deleteImage() {
        guard let cachePath = imageCachePath() else { return }
        try? FileManager.default.removeItem(at: cachePath)
    }
    
    // Helper to get NSImage from cache
    var image: NSImage? {
        guard type == .image else { return nil }
        return loadImage()
    }
    
    enum ClipboardType: String, Codable {
        case text
        case url
        case code
        case image
    }
    
    var displayContent: String {
        let maxLength = 100
        if content.count > maxLength {
            return String(content.prefix(maxLength)) + "..."
        }
        return content
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}
