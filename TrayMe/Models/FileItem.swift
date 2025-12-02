//
//  FileItem.swift
//  TrayMe
//

import Foundation
import AppKit
import os.log

/// Private logger for FileItem
private let logger = Logger(subsystem: "com.trayme.TrayMe", category: "FileItem")

struct FileItem: Identifiable, Codable {
    let id: UUID
    let url: URL
    let name: String
    let fileType: String
    let size: Int64
    let addedDate: Date
    var iconData: Data?
    var bookmarkData: Data?  // Security-scoped bookmark
    
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
    
    // Helper to populate bookmark data asynchronously (only for referenced files)
    nonisolated mutating func populateMetadata() {
        logger.debug("populateMetadata called for: \(self.url.lastPathComponent)")
        
        // Create security-scoped bookmark for referenced files
        do {
            self.bookmarkData = try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            logger.debug("Bookmark created successfully for: \(self.url.lastPathComponent) (\(self.bookmarkData?.count ?? 0) bytes)")
        } catch {
            logger.error("Failed to create bookmark for \(self.url.lastPathComponent): \(error.localizedDescription)")
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
    }
    
    // Check if referenced file still exists
    func fileExists() -> Bool {
        guard let url = resolvedURL() else {
            logger.warning("fileExists: Could not resolve URL for \(self.name)")
            return false
        }
        let exists = FileManager.default.fileExists(atPath: url.path)
        logger.debug("fileExists check for \(self.name): \(exists)")
        return exists
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

