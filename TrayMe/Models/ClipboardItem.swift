//
//  ClipboardItem.swift
//  TrayMe
//

import Foundation
import AppKit

struct ClipboardItem: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let content: String
    let timestamp: Date
    var isFavorite: Bool
    let type: ClipboardType
    
    /// Maximum content length (5MB text equivalent to prevent memory issues)
    static let maxContentLength = 5_000_000
    
    init(content: String, type: ClipboardType = .text, isFavorite: Bool = false) {
        self.id = UUID()
        // Truncate content if too long (edge case protection)
        self.content = String(content.prefix(Self.maxContentLength))
        self.timestamp = Date()
        self.isFavorite = isFavorite
        self.type = type
    }
    
    init(id: UUID, content: String, type: ClipboardType, date: Date, isFavorite: Bool) {
        self.id = id
        // Truncate content if too long (edge case protection)
        self.content = String(content.prefix(Self.maxContentLength))
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
    
    /// Word count of the content
    var wordCount: Int {
        let words = content.components(separatedBy: .whitespacesAndNewlines)
        return words.filter { !$0.isEmpty }.count
    }
    
    /// Character count of the content
    var characterCount: Int {
        content.count
    }
    
    // MARK: - Equatable & Hashable
    // Use only ID for equality and hashing since UUIDs are unique identifiers
    
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
