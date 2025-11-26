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
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        url = try container.decode(URL.self, forKey: .url)
        name = try container.decode(String.self, forKey: .name)
        fileType = try container.decode(String.self, forKey: .fileType)
        size = try container.decode(Int64.self, forKey: .size)
        addedDate = try container.decode(Date.self, forKey: .addedDate)
        iconData = try container.decodeIfPresent(Data.self, forKey: .iconData)
        bookmarkData = try container.decodeIfPresent(Data.self, forKey: .bookmarkData)
        thumbnailData = try container.decodeIfPresent(Data.self, forKey: .thumbnailData)
    }
    
    // Helper to populate icon and bookmark data asynchronously
    nonisolated mutating func populateMetadata() {
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
        } catch {
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
        case id, url, name, fileType, size, addedDate, iconData, bookmarkData, thumbnailData
    }
    
    var thumbnail: NSImage? {
        if let data = thumbnailData {
            return NSImage(data: data)
        }
        return nil
    }
    
    // Helper to resolve URL from bookmark if available
    func resolvedURL() -> URL {
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
                if isStale {
                    print("⚠️ Bookmark is stale for \(name)")
                }
                return resolvedURL
            } catch {
                print("⚠️ Failed to resolve bookmark for \(name): \(error)")
            }
        }
        // Fallback to regular URL
        return url
    }
}

