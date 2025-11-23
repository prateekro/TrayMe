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
