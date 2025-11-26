//
//  FileItem.swift
//  TrayMe
//

import Foundation
import AppKit

struct FileItem: Identifiable, Codable {
    let id: UUID
    let url: URL
    let name: String
    let fileType: String
    let size: Int64
    let addedDate: Date
    var iconData: Data?
    var bookmarkData: Data?  // Security-scoped bookmark
    var thumbnailData: Data? // Cached thumbnail for persistence
    
    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.name = url.lastPathComponent
        self.fileType = url.pathExtension
        self.addedDate = Date()
        
        // Get file size - quick operation
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            self.size = attributes[.size] as? Int64 ?? 0
        } catch {
            self.size = 0
        }
        
        // Defer heavy operations - will be done asynchronously after creation
        self.iconData = nil
        self.bookmarkData = nil
    }
    
    // Initialize with icon and bookmark data (for loading from disk)
    // Note: Relying on automatic Codable synthesis - custom decoder removed
    // Swift automatically synthesizes proper decoding for all properties
    
    // Helper to populate icon and bookmark data asynchronously
    nonisolated mutating func populateMetadata() {
        print("🔖 populateMetadata called for: \(url.lastPathComponent)")
        
        // Get file icon
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        self.iconData = icon.tiffRepresentation
        
        // Create security-scoped bookmark for referenced files
        do {
            self.bookmarkData = try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            print("✅ Bookmark created successfully for: \(url.lastPathComponent)")
            print("✅ Bookmark data size: \(bookmarkData?.count ?? 0) bytes")
        } catch {
            print("❌ Failed to create bookmark for \(url.lastPathComponent): \(error.localizedDescription)")
            self.bookmarkData = nil
        }
    }
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var icon: NSImage? {
        if let data = iconData {
            return NSImage(data: data)
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
    
    
    enum CodingKeys: String, CodingKey {
        case id, url, name, fileType, size, addedDate
        // iconData removed - regenerated instantly with NSWorkspace.shared.icon()
        // bookmarkData removed - stored separately for fast JSON loading
        // thumbnailData removed - thumbnails regenerated on demand (fast with workspace icons)
    }
    
    var thumbnail: NSImage? {
        if let data = thumbnailData {
            return NSImage(data: data)
        }
        return nil
    }
    
    // Helper to resolve URL from bookmark if available
    // Bookmarks are stored separately for fast JSON loading
    func resolvedURL() -> URL? {
        // Try to load bookmark from cache first
        let bookmarkData = FilesManager.loadBookmark(for: id) ?? self.bookmarkData
        
        // If we have bookmark data, try to resolve it
        if let bookmarkData = bookmarkData {
            do {
                var isStale = false
                let resolvedURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                // Don't check fileExists here - expensive!
                // Let the caller handle file access errors
                return resolvedURL
            } catch {
                // Bookmark failed - return fallback URL without validation
                // File existence will be verified when actually accessed
                return url
            }
        }
        // No bookmark - return URL (validation happens on access)
        return url
    }
}

