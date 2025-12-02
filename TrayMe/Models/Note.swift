//
//  Note.swift
//  TrayMe
//

import Foundation

struct Note: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var content: String
    var createdDate: Date
    var modifiedDate: Date
    var isPinned: Bool
    
    /// Maximum title length for display and storage
    static let maxTitleLength = 500
    
    /// Maximum content length (10MB text equivalent)
    static let maxContentLength = 10_000_000
    
    init(title: String = "", content: String = "", isPinned: Bool = false) {
        self.id = UUID()
        // Truncate title if too long
        self.title = String(title.prefix(Self.maxTitleLength))
        // Truncate content if too long (edge case protection)
        self.content = String(content.prefix(Self.maxContentLength))
        self.createdDate = Date()
        self.modifiedDate = Date()
        self.isPinned = isPinned
    }
    
    mutating func update(title: String? = nil, content: String? = nil) {
        if let title = title {
            self.title = String(title.prefix(Self.maxTitleLength))
        }
        if let content = content {
            self.content = String(content.prefix(Self.maxContentLength))
        }
        self.modifiedDate = Date()
    }
    
    var displayTitle: String {
        if !title.isEmpty {
            return title
        }
        // Extract first line from content
        let firstLine = content.components(separatedBy: .newlines).first ?? "Untitled Note"
        return firstLine.isEmpty ? "Untitled Note" : String(firstLine.prefix(30))
    }
    
    var preview: String {
        let maxLength = 100
        if content.count > maxLength {
            return String(content.prefix(maxLength)) + "..."
        }
        return content
    }
    
    /// Word count of the note content
    var wordCount: Int {
        let words = content.components(separatedBy: .whitespacesAndNewlines)
        return words.filter { !$0.isEmpty }.count
    }
    
    /// Character count of the note content
    var characterCount: Int {
        content.count
    }
}
