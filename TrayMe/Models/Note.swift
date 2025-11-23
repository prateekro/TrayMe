//
//  Note.swift
//  TrayMe
//

import Foundation

struct Note: Identifiable, Codable {
    let id: UUID
    var title: String
    var content: String
    var createdDate: Date
    var modifiedDate: Date
    var isPinned: Bool
    
    init(title: String = "", content: String = "", isPinned: Bool = false) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.createdDate = Date()
        self.modifiedDate = Date()
        self.isPinned = isPinned
    }
    
    mutating func update(title: String? = nil, content: String? = nil) {
        if let title = title {
            self.title = title
        }
        if let content = content {
            self.content = content
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
}
