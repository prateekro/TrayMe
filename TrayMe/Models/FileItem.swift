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
    
    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.name = url.lastPathComponent
        self.fileType = url.pathExtension
        self.addedDate = Date()
        
        // Get file size
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            self.size = attributes[.size] as? Int64 ?? 0
        } catch {
            self.size = 0
        }
        
        // Get file icon
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        self.iconData = icon.tiffRepresentation
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
        case id, url, name, fileType, size, addedDate, iconData
    }
}
