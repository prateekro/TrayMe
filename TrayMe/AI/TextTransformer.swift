//
//  TextTransformer.swift
//  TrayMe
//
//  Smart text transformations for clipboard content

import Foundation

/// Available text transformation types
enum TextTransformation: String, CaseIterable, Identifiable {
    case uppercase = "UPPERCASE"
    case lowercase = "lowercase"
    case titleCase = "Title Case"
    case camelCase = "camelCase"
    case snakeCase = "snake_case"
    case kebabCase = "kebab-case"
    case pascalCase = "PascalCase"
    case constantCase = "CONSTANT_CASE"
    case bulletPoints = "• Bullet Points"
    case numberedList = "1. Numbered List"
    case jsonPrettify = "JSON Prettify"
    case jsonMinify = "JSON Minify"
    case urlEncode = "URL Encode"
    case urlDecode = "URL Decode"
    case base64Encode = "Base64 Encode"
    case base64Decode = "Base64 Decode"
    case markdownToPlain = "Markdown → Plain"
    case trimWhitespace = "Trim Whitespace"
    case removeExtraSpaces = "Remove Extra Spaces"
    case sortLines = "Sort Lines"
    case reverseLines = "Reverse Lines"
    case uniqueLines = "Unique Lines"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .uppercase, .lowercase, .titleCase:
            return "textformat"
        case .camelCase, .snakeCase, .kebabCase, .pascalCase, .constantCase:
            return "textformat.abc"
        case .bulletPoints, .numberedList:
            return "list.bullet"
        case .jsonPrettify, .jsonMinify:
            return "curlybraces"
        case .urlEncode, .urlDecode:
            return "link"
        case .base64Encode, .base64Decode:
            return "lock.fill"
        case .markdownToPlain:
            return "doc.plaintext"
        case .trimWhitespace, .removeExtraSpaces:
            return "arrow.left.and.right.text.vertical"
        case .sortLines, .reverseLines, .uniqueLines:
            return "arrow.up.arrow.down"
        }
    }
    
    var category: TransformationCategory {
        switch self {
        case .uppercase, .lowercase, .titleCase:
            return .caseConversion
        case .camelCase, .snakeCase, .kebabCase, .pascalCase, .constantCase:
            return .programmingCase
        case .bulletPoints, .numberedList:
            return .listFormatting
        case .jsonPrettify, .jsonMinify:
            return .jsonFormatting
        case .urlEncode, .urlDecode:
            return .urlEncoding
        case .base64Encode, .base64Decode:
            return .base64Encoding
        case .markdownToPlain:
            return .markdownConversion
        case .trimWhitespace, .removeExtraSpaces:
            return .whitespace
        case .sortLines, .reverseLines, .uniqueLines:
            return .lineOperations
        }
    }
}

/// Categories for grouping transformations
enum TransformationCategory: String, CaseIterable {
    case caseConversion = "Case Conversion"
    case programmingCase = "Programming Case"
    case listFormatting = "List Formatting"
    case jsonFormatting = "JSON"
    case urlEncoding = "URL Encoding"
    case base64Encoding = "Base64"
    case markdownConversion = "Markdown"
    case whitespace = "Whitespace"
    case lineOperations = "Line Operations"
    
    var transformations: [TextTransformation] {
        TextTransformation.allCases.filter { $0.category == self }
    }
}

/// Text transformer for applying smart transformations
@MainActor
class TextTransformer: ObservableObject {
    /// Shared instance
    static let shared = TextTransformer()
    
    // MARK: - Cached Regex Patterns
    
    /// Cache compiled regex patterns for better performance
    private lazy var multipleSpacesRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #" {2,}"#, options: [])
    }()
    
    private lazy var multipleNewlinesRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"\n{3,}"#, options: [])
    }()
    
    private lazy var boldMarkdownRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"\*\*([^*]+)\*\*"#, options: [])
    }()
    
    private lazy var italicMarkdownRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"\*([^*]+)\*"#, options: [])
    }()
    
    private lazy var inlineCodeRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"`([^`]+)`"#, options: [])
    }()
    
    private lazy var markdownLinkRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"\[([^\]]+)\]\([^)]+\)"#, options: [])
    }()
    
    private lazy var markdownImageRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"!\[([^\]]*)\]\([^)]+\)"#, options: [])
    }()
    
    private lazy var markdownCodeBlockRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"```[^`]*```"#, options: [])
    }()
    
    private lazy var markdownHorizontalRuleRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"^[-*_]{3,}$"#, options: [])
    }()
    
    private lazy var markdownBlockquoteRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"^>\s?"#, options: [])
    }()
    
    private init() {}
    
    /// Apply a transformation to text
    /// - Parameters:
    ///   - transformation: Type of transformation to apply
    ///   - text: Input text
    /// - Returns: Transformed text, or original if transformation fails
    func transform(_ text: String, using transformation: TextTransformation) -> String {
        switch transformation {
        case .uppercase:
            return text.uppercased()
            
        case .lowercase:
            return text.lowercased()
            
        case .titleCase:
            return toTitleCase(text)
            
        case .camelCase:
            return toCamelCase(text)
            
        case .snakeCase:
            return toSnakeCase(text)
            
        case .kebabCase:
            return toKebabCase(text)
            
        case .pascalCase:
            return toPascalCase(text)
            
        case .constantCase:
            return toConstantCase(text)
            
        case .bulletPoints:
            return toBulletPoints(text)
            
        case .numberedList:
            return toNumberedList(text)
            
        case .jsonPrettify:
            return prettifyJSON(text) ?? text
            
        case .jsonMinify:
            return minifyJSON(text) ?? text
            
        case .urlEncode:
            return text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
            
        case .urlDecode:
            return text.removingPercentEncoding ?? text
            
        case .base64Encode:
            return Data(text.utf8).base64EncodedString()
            
        case .base64Decode:
            if let data = Data(base64Encoded: text),
               let decoded = String(data: data, encoding: .utf8) {
                return decoded
            }
            return text
            
        case .markdownToPlain:
            return markdownToPlainText(text)
            
        case .trimWhitespace:
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
            
        case .removeExtraSpaces:
            return removeExtraSpaces(text)
            
        case .sortLines:
            return sortLines(text)
            
        case .reverseLines:
            return reverseLines(text)
            
        case .uniqueLines:
            return uniqueLines(text)
        }
    }
    
    // MARK: - Case Transformations
    
    private func toTitleCase(_ text: String) -> String {
        text.capitalized
    }
    
    private func toCamelCase(_ text: String) -> String {
        let words = extractWords(text)
        guard !words.isEmpty else { return text }
        
        let first = words[0].lowercased()
        let rest = words.dropFirst().map { $0.capitalized }
        
        return ([first] + rest).joined()
    }
    
    private func toPascalCase(_ text: String) -> String {
        extractWords(text).map { $0.capitalized }.joined()
    }
    
    private func toSnakeCase(_ text: String) -> String {
        extractWords(text).map { $0.lowercased() }.joined(separator: "_")
    }
    
    private func toKebabCase(_ text: String) -> String {
        extractWords(text).map { $0.lowercased() }.joined(separator: "-")
    }
    
    private func toConstantCase(_ text: String) -> String {
        extractWords(text).map { $0.uppercased() }.joined(separator: "_")
    }
    
    /// Extract words from text (handles camelCase, snake_case, spaces, etc.)
    private func extractWords(_ text: String) -> [String] {
        // Split by common separators
        var result = text.components(separatedBy: CharacterSet(charactersIn: " _-./\\"))
        
        // Further split camelCase
        result = result.flatMap { word -> [String] in
            var words: [String] = []
            var currentWord = ""
            
            for char in word {
                if char.isUppercase && !currentWord.isEmpty {
                    words.append(currentWord)
                    currentWord = String(char)
                } else {
                    currentWord.append(char)
                }
            }
            
            if !currentWord.isEmpty {
                words.append(currentWord)
            }
            
            return words
        }
        
        return result.filter { !$0.isEmpty }
    }
    
    // MARK: - List Formatting
    
    private func toBulletPoints(_ text: String) -> String {
        text.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { "• \($0.trimmingCharacters(in: .whitespaces))" }
            .joined(separator: "\n")
    }
    
    private func toNumberedList(_ text: String) -> String {
        text.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .enumerated()
            .map { index, line in "\(index + 1). \(line.trimmingCharacters(in: .whitespaces))" }
            .joined(separator: "\n")
    }
    
    // MARK: - JSON Formatting
    
    private func prettifyJSON(_ text: String) -> String? {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return nil
        }
        return prettyString
    }
    
    private func minifyJSON(_ text: String) -> String? {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let minifiedData = try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys]),
              let minifiedString = String(data: minifiedData, encoding: .utf8) else {
            return nil
        }
        return minifiedString
    }
    
    // MARK: - Markdown Conversion
    
    private func markdownToPlainText(_ text: String) -> String {
        var result = text
        
        // Remove headers (# ## ### etc)
        result = result.replacingOccurrences(of: #"^#{1,6}\s+"#, with: "", options: .regularExpression)
        
        // Remove bold using cached regex
        if let regex = boldMarkdownRegex {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "$1")
        }
        
        result = result.replacingOccurrences(of: #"__([^_]+)__"#, with: "$1", options: .regularExpression)
        
        // Remove italic using cached regex
        if let regex = italicMarkdownRegex {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "$1")
        }
        
        result = result.replacingOccurrences(of: #"_([^_]+)_"#, with: "$1", options: .regularExpression)
        
        // Remove inline code using cached regex
        if let regex = inlineCodeRegex {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "$1")
        }
        
        // Remove links [text](url) -> text using cached regex
        if let regex = markdownLinkRegex {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "$1")
        }
        
        // Remove images ![alt](url) using cached regex
        if let regex = markdownImageRegex {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "$1")
        }
        
        // Remove code blocks using cached regex
        if let regex = markdownCodeBlockRegex {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
        }
        
        // Remove horizontal rules using cached regex
        if let regex = markdownHorizontalRuleRegex {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
        }
        
        // Remove blockquotes using cached regex
        if let regex = markdownBlockquoteRegex {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Whitespace Operations
    
    private func removeExtraSpaces(_ text: String) -> String {
        var result = text
        
        // Replace multiple spaces with single space
        if let regex = multipleSpacesRegex {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: " ")
        }
        
        // Replace multiple newlines with double newline
        if let regex = multipleNewlinesRegex {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "\n\n")
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Line Operations
    
    private func sortLines(_ text: String) -> String {
        text.components(separatedBy: .newlines)
            .sorted()
            .joined(separator: "\n")
    }
    
    private func reverseLines(_ text: String) -> String {
        text.components(separatedBy: .newlines)
            .reversed()
            .joined(separator: "\n")
    }
    
    private func uniqueLines(_ text: String) -> String {
        var seen = Set<String>()
        return text.components(separatedBy: .newlines)
            .filter { line in
                if seen.contains(line) {
                    return false
                }
                seen.insert(line)
                return true
            }
            .joined(separator: "\n")
    }
    
    // MARK: - Batch Transformations
    
    /// Check if a transformation is applicable to the given text
    func isApplicable(_ transformation: TextTransformation, to text: String) -> Bool {
        switch transformation {
        case .jsonPrettify, .jsonMinify:
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) ||
                   (trimmed.hasPrefix("[") && trimmed.hasSuffix("]"))
        case .base64Decode:
            // Check if it looks like Base64
            let base64Pattern = #"^[A-Za-z0-9+/]+={0,2}$"#
            if let regex = try? NSRegularExpression(pattern: base64Pattern) {
                let range = NSRange(text.startIndex..., in: text)
                return regex.firstMatch(in: text, options: [], range: range) != nil
            }
            return false
        case .urlDecode:
            return text.contains("%")
        case .markdownToPlain:
            // Check for common markdown patterns
            let markdownPatterns = ["#", "**", "*", "`", "[", "!["]
            return markdownPatterns.contains { text.contains($0) }
        default:
            return true
        }
    }
    
    /// Get applicable transformations for text
    func applicableTransformations(for text: String) -> [TextTransformation] {
        TextTransformation.allCases.filter { isApplicable($0, to: text) }
    }
}
