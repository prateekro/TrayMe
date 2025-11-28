//
//  SnippetModel.swift
//  TrayMe
//
//  Data model for text snippets with variable support

import Foundation

/// A text snippet with trigger, expansion, and variable support
struct Snippet: Identifiable, Codable, Equatable {
    let id: UUID
    var trigger: String          // e.g., "//email"
    var expansion: String        // Full text to expand
    var category: String?
    var usageCount: Int
    var lastUsed: Date?
    var variables: [String]      // e.g., ["{{date}}", "{{clipboard}}"]
    var createdAt: Date
    var modifiedAt: Date
    
    init(
        id: UUID = UUID(),
        trigger: String,
        expansion: String,
        category: String? = nil,
        usageCount: Int = 0,
        lastUsed: Date? = nil,
        variables: [String]? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.trigger = trigger
        self.expansion = expansion
        self.category = category
        self.usageCount = usageCount
        self.lastUsed = lastUsed
        self.variables = variables ?? Self.extractVariables(from: expansion)
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
    
    /// Extract variables from expansion text
    static func extractVariables(from text: String) -> [String] {
        let pattern = #"\{\{([a-zA-Z_][a-zA-Z0-9_]*)\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, options: [], range: range)
        
        var variables: [String] = []
        var seen = Set<String>()
        
        for match in matches {
            if let swiftRange = Range(match.range, in: text) {
                let variable = String(text[swiftRange])
                if !seen.contains(variable) {
                    seen.insert(variable)
                    variables.append(variable)
                }
            }
        }
        
        return variables
    }
    
    /// Expand the snippet with variable substitution
    func expand(context: SnippetContext = .current) -> String {
        var result = expansion
        
        // Replace built-in variables
        for variable in variables {
            let replacement = context.getValue(for: variable)
            result = result.replacingOccurrences(of: variable, with: replacement)
        }
        
        return result
    }
    
    /// Preview of the expansion (first 100 chars)
    var preview: String {
        let trimmed = expansion.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 100 {
            return String(trimmed.prefix(100)) + "..."
        }
        return trimmed
    }
    
    /// Check if trigger conflicts with another
    func conflicts(with other: Snippet) -> Bool {
        // Check if one trigger is prefix of another
        trigger.hasPrefix(other.trigger) || other.trigger.hasPrefix(trigger)
    }
    
    /// Update usage statistics
    mutating func recordUsage() {
        usageCount += 1
        lastUsed = Date()
    }
    
    /// Update variables list based on current expansion
    mutating func refreshVariables() {
        variables = Self.extractVariables(from: expansion)
    }
}

// MARK: - Snippet Context

/// Context for variable substitution in snippets
struct SnippetContext {
    let date: Date
    let clipboard: String?
    let customValues: [String: String]
    
    /// Current context with live values
    static var current: SnippetContext {
        SnippetContext(
            date: Date(),
            clipboard: NSPasteboard.general.string(forType: .string),
            customValues: [:]
        )
    }
    
    /// Get value for a variable
    func getValue(for variable: String) -> String {
        switch variable {
        case "{{date}}":
            return formatDate(style: .short)
        case "{{date_long}}":
            return formatDate(style: .long)
        case "{{time}}":
            return formatTime()
        case "{{datetime}}":
            return formatDateTime()
        case "{{clipboard}}":
            return clipboard ?? ""
        case "{{cursor}}":
            return "" // Cursor position is handled by the UI
        case "{{uuid}}":
            return UUID().uuidString
        case "{{uuid_short}}":
            return String(UUID().uuidString.prefix(8))
        case "{{year}}":
            return String(Calendar.current.component(.year, from: date))
        case "{{month}}":
            return String(format: "%02d", Calendar.current.component(.month, from: date))
        case "{{day}}":
            return String(format: "%02d", Calendar.current.component(.day, from: date))
        case "{{weekday}}":
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        case "{{timestamp}}":
            return String(Int(date.timeIntervalSince1970))
        default:
            // Check custom values
            let key = variable.replacingOccurrences(of: "{{", with: "")
                              .replacingOccurrences(of: "}}", with: "")
            return customValues[key] ?? variable
        }
    }
    
    private func formatDate(style: DateFormatter.Style) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        return formatter.string(from: date)
    }
    
    private func formatTime() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDateTime() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Snippet Category

/// Categories for organizing snippets
struct SnippetCategory: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var icon: String
    var color: String
    
    init(id: UUID = UUID(), name: String, icon: String = "folder", color: String = "blue") {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
    }
    
    /// Default categories
    static let defaultCategories: [SnippetCategory] = [
        SnippetCategory(name: "General", icon: "doc.text", color: "gray"),
        SnippetCategory(name: "Email", icon: "envelope", color: "blue"),
        SnippetCategory(name: "Code", icon: "chevron.left.forwardslash.chevron.right", color: "purple"),
        SnippetCategory(name: "Personal", icon: "person", color: "green"),
        SnippetCategory(name: "Work", icon: "briefcase", color: "orange"),
    ]
}

// MARK: - Import/Export

extension Snippet {
    /// Export format for snippets
    struct ExportData: Codable {
        let version: Int
        let exportDate: Date
        let snippets: [Snippet]
        let categories: [SnippetCategory]
        
        init(snippets: [Snippet], categories: [SnippetCategory]) {
            self.version = 1
            self.exportDate = Date()
            self.snippets = snippets
            self.categories = categories
        }
    }
    
    /// Export snippets to JSON data
    static func export(snippets: [Snippet], categories: [SnippetCategory]) -> Data? {
        let exportData = ExportData(snippets: snippets, categories: categories)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(exportData)
    }
    
    /// Import snippets from JSON data
    static func importData(_ data: Data) -> (snippets: [Snippet], categories: [SnippetCategory])? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let exportData = try? decoder.decode(ExportData.self, from: data) else {
            return nil
        }
        
        return (exportData.snippets, exportData.categories)
    }
}

// MARK: - Variable Definitions

/// Built-in variables available for snippets
enum BuiltInVariable: String, CaseIterable {
    case date = "{{date}}"
    case dateLong = "{{date_long}}"
    case time = "{{time}}"
    case datetime = "{{datetime}}"
    case clipboard = "{{clipboard}}"
    case cursor = "{{cursor}}"
    case uuid = "{{uuid}}"
    case uuidShort = "{{uuid_short}}"
    case year = "{{year}}"
    case month = "{{month}}"
    case day = "{{day}}"
    case weekday = "{{weekday}}"
    case timestamp = "{{timestamp}}"
    
    var displayName: String {
        switch self {
        case .date: return "Date (short)"
        case .dateLong: return "Date (long)"
        case .time: return "Time"
        case .datetime: return "Date & Time"
        case .clipboard: return "Clipboard"
        case .cursor: return "Cursor Position"
        case .uuid: return "UUID"
        case .uuidShort: return "UUID (short)"
        case .year: return "Year"
        case .month: return "Month"
        case .day: return "Day"
        case .weekday: return "Weekday"
        case .timestamp: return "Timestamp"
        }
    }
    
    var description: String {
        switch self {
        case .date: return "Short date format (e.g., 11/28/24)"
        case .dateLong: return "Long date format (e.g., November 28, 2024)"
        case .time: return "Current time (e.g., 10:30 AM)"
        case .datetime: return "Date and time combined"
        case .clipboard: return "Current clipboard content"
        case .cursor: return "Position cursor here after expansion"
        case .uuid: return "Random UUID"
        case .uuidShort: return "First 8 characters of a UUID"
        case .year: return "Current year (e.g., 2024)"
        case .month: return "Current month (01-12)"
        case .day: return "Current day (01-31)"
        case .weekday: return "Day of week (e.g., Thursday)"
        case .timestamp: return "Unix timestamp"
        }
    }
}

import AppKit
