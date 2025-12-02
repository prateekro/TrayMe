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
    let category: ClipboardCategory
    let sourceApp: String?
    
    init(content: String, type: ClipboardType = .text, category: ClipboardCategory = .text, isFavorite: Bool = false, sourceApp: String? = nil) {
        self.id = UUID()
        self.content = content
        self.timestamp = Date()
        self.isFavorite = isFavorite
        self.type = type
        self.category = category
        self.sourceApp = sourceApp
    }
    
    init(id: UUID, content: String, type: ClipboardType, category: ClipboardCategory = .text, date: Date, isFavorite: Bool, sourceApp: String? = nil) {
        self.id = id
        self.content = content
        self.timestamp = date
        self.isFavorite = isFavorite
        self.type = type
        self.category = category
        self.sourceApp = sourceApp
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
    
    /// Icon for the category badge
    var categoryIcon: String {
        category.icon
    }
    
    /// Color for the category badge
    var categoryColor: String {
        category.colorName
    }
}

/// Smart clipboard categorization
enum ClipboardCategory: String, Codable, CaseIterable {
    case text
    case url
    case email
    case phone
    case code
    case json
    case address
    case image
    case file
    
    // Cached URL detector for performance
    private static let urlDetector: NSDataDetector? = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
    
    /// Icon name for the category
    var icon: String {
        switch self {
        case .text: return "doc.text"
        case .url: return "link"
        case .email: return "envelope"
        case .phone: return "phone"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .json: return "curlybraces"
        case .address: return "mappin.and.ellipse"
        case .image: return "photo"
        case .file: return "doc"
        }
    }
    
    /// Color name for SwiftUI
    var colorName: String {
        switch self {
        case .text: return "secondary"
        case .url: return "blue"
        case .email: return "orange"
        case .phone: return "green"
        case .code: return "purple"
        case .json: return "indigo"
        case .address: return "red"
        case .image: return "pink"
        case .file: return "gray"
        }
    }
    
    /// Detect category from content
    static func detect(from content: String) -> ClipboardCategory {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // URL detection (most specific first)
        if isURL(trimmed) {
            return .url
        }
        
        // Email detection
        if isEmail(trimmed) {
            return .email
        }
        
        // Phone number detection
        if isPhoneNumber(trimmed) {
            return .phone
        }
        
        // JSON detection
        if isJSON(trimmed) {
            return .json
        }
        
        // Code detection (heuristics)
        if looksLikeCode(trimmed) {
            return .code
        }
        
        // Address detection (basic)
        if looksLikeAddress(trimmed) {
            return .address
        }
        
        return .text
    }
    
    private static func isURL(_ content: String) -> Bool {
        // Check for common URL patterns
        if content.hasPrefix("http://") || content.hasPrefix("https://") || content.hasPrefix("ftp://") {
            if let detector = urlDetector,
               let match = detector.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
               match.range.length == content.count {
                return true
            }
        }
        return false
    }
    
    private static func isEmail(_ content: String) -> Bool {
        let emailPattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return content.range(of: emailPattern, options: .regularExpression) != nil
    }
    
    private static func isPhoneNumber(_ content: String) -> Bool {
        // Match common phone number formats
        let phonePatterns = [
            #"^\+?[\d\s\-\(\)]{10,}$"#,  // International format
            #"^\(\d{3}\)\s?\d{3}[\-\s]?\d{4}$"#,  // (123) 456-7890
            #"^\d{3}[\-\s]?\d{3}[\-\s]?\d{4}$"#,  // 123-456-7890
        ]
        
        for pattern in phonePatterns {
            if content.range(of: pattern, options: .regularExpression) != nil {
                // Additional check: should have mostly digits
                let digits = content.filter { $0.isNumber }
                if digits.count >= 10 {
                    return true
                }
            }
        }
        return false
    }
    
    private static func isJSON(_ content: String) -> Bool {
        // Check if it looks like JSON
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) ||
           (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) {
            // Try to parse as JSON
            if let data = trimmed.data(using: .utf8) {
                do {
                    _ = try JSONSerialization.jsonObject(with: data, options: [])
                    return true
                } catch {
                    return false
                }
            }
        }
        return false
    }
    
    private static func looksLikeCode(_ content: String) -> Bool {
        // Code indicators
        let codeIndicators = [
            "function ", "func ", "def ", "class ", "struct ", "enum ",
            "import ", "from ", "require(", "include ",
            "const ", "let ", "var ", "public ", "private ", "protected ",
            "if (", "for (", "while (", "switch (",
            "return ", "throw ", "catch ", "try {",
            "=>", "->", "::", "&&", "||",
            "$(", "#{", "<%", "%>",
        ]
        
        for indicator in codeIndicators {
            if content.contains(indicator) {
                return true
            }
        }
        
        // Check for common code patterns
        let hasMultipleBraces = content.filter { $0 == "{" || $0 == "}" }.count >= 2
        let hasSemicolons = content.contains(";")
        let hasIndentation = content.contains("\n    ") || content.contains("\n\t")
        
        return (hasMultipleBraces && hasSemicolons) || (hasMultipleBraces && hasIndentation)
    }
    
    private static func looksLikeAddress(_ content: String) -> Bool {
        // Basic address detection
        let addressIndicators = [
            "Street", "St.", "Avenue", "Ave.", "Boulevard", "Blvd.",
            "Road", "Rd.", "Drive", "Dr.", "Lane", "Ln.",
            "Court", "Ct.", "Circle", "Cir.", "Way", "Place", "Pl.",
        ]
        
        // Check for ZIP code pattern
        let hasZipCode = content.range(of: #"\b\d{5}(-\d{4})?\b"#, options: .regularExpression) != nil
        
        // Check for address indicators
        for indicator in addressIndicators {
            if content.localizedCaseInsensitiveContains(indicator) && hasZipCode {
                return true
            }
        }
        
        return false
    }
}
