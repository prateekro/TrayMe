//
//  Note.swift
//  TrayMe
//

import Foundation
import SwiftUI

enum NoteColor: String, Codable, CaseIterable {
    case none = "none"
    case red = "red"
    case orange = "orange"
    case yellow = "yellow"
    case green = "green"
    case blue = "blue"
    case purple = "purple"
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .red: return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .blue: return "Blue"
        case .purple: return "Purple"
        }
    }
    
    var swiftUIColor: Color {
        switch self {
        case .none: return .clear
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        }
    }
}

struct Note: Identifiable, Codable {
    let id: UUID
    var title: String
    var content: String
    var createdDate: Date
    var modifiedDate: Date
    var isPinned: Bool
    var color: NoteColor
    
    init(title: String = "", content: String = "", isPinned: Bool = false, color: NoteColor = .none) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.createdDate = Date()
        self.modifiedDate = Date()
        self.isPinned = isPinned
        self.color = color
    }
    
    // Custom decoding to handle existing notes without color
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        createdDate = try container.decode(Date.self, forKey: .createdDate)
        modifiedDate = try container.decode(Date.self, forKey: .modifiedDate)
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
        color = try container.decodeIfPresent(NoteColor.self, forKey: .color) ?? .none
    }
    
    mutating func update(title: String? = nil, content: String? = nil, color: NoteColor? = nil) {
        if let title = title {
            self.title = title
        }
        if let content = content {
            self.content = content
        }
        if let color = color {
            self.color = color
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
    
    // MARK: - Statistics
    
    /// Total word count across title and content
    var wordCount: Int {
        let combined = title + " " + content
        let words = combined.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return words.count
    }
    
    /// Total character count across title and content
    var characterCount: Int {
        return title.count + content.count
    }
    
    /// Line count of the note content only (title is single line by design)
    var lineCount: Int {
        var count = title.isEmpty ? 0 : 1  // Count title as 1 line if not empty
        let contentLines = content.components(separatedBy: .newlines)
        count += contentLines.count
        return max(1, count)
    }
}
