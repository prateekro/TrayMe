//
//  AIClipboardEngine.swift
//  TrayMe
//
//  Smart clipboard categorization and context-aware suggestions using on-device NLP

import Foundation
import NaturalLanguage
import AppKit

/// Content categories for clipboard items
enum ClipboardCategory: String, Codable, CaseIterable {
    case code = "code"
    case url = "url"
    case email = "email"
    case address = "address"
    case phone = "phone"
    case credential = "credential"
    case json = "json"
    case markdown = "markdown"
    case plainText = "plainText"
    
    var displayName: String {
        switch self {
        case .code: return "Code"
        case .url: return "URL"
        case .email: return "Email"
        case .address: return "Address"
        case .phone: return "Phone"
        case .credential: return "Credential"
        case .json: return "JSON"
        case .markdown: return "Markdown"
        case .plainText: return "Plain Text"
        }
    }
    
    var icon: String {
        switch self {
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .url: return "link"
        case .email: return "envelope"
        case .address: return "mappin.and.ellipse"
        case .phone: return "phone"
        case .credential: return "key.fill"
        case .json: return "curlybraces"
        case .markdown: return "text.badge.checkmark"
        case .plainText: return "doc.text"
        }
    }
}

/// Context-aware suggestion with scoring
struct ClipboardSuggestion: Identifiable {
    let id = UUID()
    let item: ClipboardItem
    let score: Double
    let reason: String
}

/// AI-powered clipboard engine for smart categorization and suggestions
@MainActor
class AIClipboardEngine: ObservableObject {
    /// Shared instance
    static let shared = AIClipboardEngine()
    
    /// Category cache with LRU eviction
    private var categoryCache: [String: ClipboardCategory] = [:]
    private var cacheOrder: [String] = []
    private let maxCacheSize = 500
    
    /// NLP tagger for entity recognition
    private let tagger: NLTagger
    
    /// Context analyzer for app-aware suggestions
    private let contextAnalyzer = ContextAnalyzer.shared
    
    /// Text transformer for smart transformations
    let textTransformer = TextTransformer.shared
    
    init() {
        // Initialize NLP tagger with relevant tag schemes
        tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass, .language])
    }
    
    // MARK: - Categorization
    
    /// Categorize content using on-device NLP
    /// Performance target: < 5ms per item
    /// - Parameter content: Text content to categorize
    /// - Returns: Detected category
    func categorize(_ content: String) -> ClipboardCategory {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check cache first (O(1) lookup)
        let cacheKey = String(trimmedContent.prefix(200)) // Use prefix for cache key
        if let cached = categoryCache[cacheKey] {
            updateCacheOrder(cacheKey)
            return cached
        }
        
        // Perform categorization
        let category = performCategorization(trimmedContent)
        
        // Cache result
        cacheCategory(cacheKey, category: category)
        
        return category
    }
    
    /// Internal categorization logic
    private func performCategorization(_ content: String) -> ClipboardCategory {
        // Quick pattern checks first (fastest)
        
        // Check for URLs
        if isURL(content) {
            return .url
        }
        
        // Check for email addresses
        if isEmail(content) {
            return .email
        }
        
        // Check for phone numbers
        if isPhoneNumber(content) {
            return .phone
        }
        
        // Check for JSON
        if isJSON(content) {
            return .json
        }
        
        // Check for credentials (API keys, passwords, tokens)
        if isCredential(content) {
            return .credential
        }
        
        // Check for code patterns
        if isCode(content) {
            return .code
        }
        
        // Check for markdown
        if isMarkdown(content) {
            return .markdown
        }
        
        // Use NLP for address detection
        if isAddress(content) {
            return .address
        }
        
        return .plainText
    }
    
    // MARK: - Pattern Detection
    
    private func isURL(_ content: String) -> Bool {
        // Fast regex check for URLs
        let urlPattern = #"^(https?|ftp)://[^\s/$.?#].[^\s]*$"#
        if let regex = try? NSRegularExpression(pattern: urlPattern, options: .caseInsensitive) {
            let range = NSRange(content.startIndex..., in: content)
            return regex.firstMatch(in: content, options: [], range: range) != nil
        }
        return false
    }
    
    private func isEmail(_ content: String) -> Bool {
        let emailPattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        if let regex = try? NSRegularExpression(pattern: emailPattern, options: .caseInsensitive) {
            let range = NSRange(content.startIndex..., in: content)
            return regex.firstMatch(in: content, options: [], range: range) != nil
        }
        return false
    }
    
    private func isPhoneNumber(_ content: String) -> Bool {
        // Match various phone formats
        let phonePattern = #"^[\+]?[(]?[0-9]{1,3}[)]?[-\s\.]?[(]?[0-9]{1,4}[)]?[-\s\.]?[0-9]{1,4}[-\s\.]?[0-9]{1,9}$"#
        if let regex = try? NSRegularExpression(pattern: phonePattern, options: []) {
            let range = NSRange(content.startIndex..., in: content)
            return regex.firstMatch(in: content, options: [], range: range) != nil
        }
        return false
    }
    
    private func isJSON(_ content: String) -> Bool {
        // Quick check for JSON structure
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) ||
              (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) else {
            return false
        }
        
        // Validate JSON parsing
        guard let data = content.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data, options: [])) != nil
    }
    
    private func isCredential(_ content: String) -> Bool {
        // Check for common credential patterns
        let credentialPatterns = [
            #"^(sk|pk|api|key|token|secret|password|pwd|pass)[_-]?[a-zA-Z0-9]{16,}$"#,  // API keys
            #"^[A-Za-z0-9+/]{32,}={0,2}$"#,  // Base64 encoded secrets
            #"^ghp_[a-zA-Z0-9]{36}$"#,  // GitHub personal access token
            #"^xox[baprs]-[0-9]{10,13}-[0-9]{10,13}[a-zA-Z0-9-]*$"#,  // Slack tokens
            #"^AKIA[0-9A-Z]{16}$"#,  // AWS access key
            #"^-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----"#,  // Private keys
        ]
        
        for pattern in credentialPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(content.startIndex..., in: content)
                if regex.firstMatch(in: content, options: [], range: range) != nil {
                    return true
                }
            }
        }
        return false
    }
    
    private func isCode(_ content: String) -> Bool {
        // Check for code patterns
        let codeIndicators = [
            // Function/method declarations
            "func ", "function ", "def ", "public ", "private ", "protected ",
            "class ", "struct ", "enum ", "interface ",
            // Common syntax
            "import ", "require(", "include ", "#include",
            "const ", "let ", "var ", "return ",
            "if (", "if(", "for (", "for(", "while (", "while(",
            // Operators and symbols common in code
            "=> ", "->", ":::", "===", "!==",
            // Brackets pattern (more than 2 curly braces suggest code)
        ]
        
        for indicator in codeIndicators {
            if content.contains(indicator) {
                return true
            }
        }
        
        // Check for balanced braces (common in code)
        let openBraces = content.filter { $0 == "{" }.count
        let closeBraces = content.filter { $0 == "}" }.count
        if openBraces > 1 && openBraces == closeBraces {
            return true
        }
        
        return false
    }
    
    private func isMarkdown(_ content: String) -> Bool {
        // Check for markdown patterns
        let markdownPatterns = [
            #"^#{1,6}\s"#,  // Headers
            #"\*\*[^*]+\*\*"#,  // Bold
            #"\*[^*]+\*"#,  // Italic
            #"\[.+\]\(.+\)"#,  // Links
            #"^\s*[-*+]\s"#,  // Lists
            #"^\s*\d+\.\s"#,  // Numbered lists
            #"```"#,  // Code blocks
            #"^\s*>"#,  // Blockquotes
        ]
        
        for pattern in markdownPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) {
                let range = NSRange(content.startIndex..., in: content)
                if regex.firstMatch(in: content, options: [], range: range) != nil {
                    return true
                }
            }
        }
        return false
    }
    
    private func isAddress(_ content: String) -> Bool {
        // Use NLP tagger for address detection
        tagger.string = content
        
        var foundPlaceName = false
        
        tagger.enumerateTags(in: content.startIndex..<content.endIndex, unit: .word, scheme: .nameType) { tag, _ in
            if tag == .placeName {
                foundPlaceName = true
                return false // Stop enumeration
            }
            return true
        }
        
        // Also check for address patterns
        let addressPatterns = [
            #"\d+\s+[\w\s]+(?:Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Drive|Dr|Lane|Ln|Way|Court|Ct)"#,
            #"[A-Z]{2}\s+\d{5}(?:-\d{4})?"#,  // US ZIP code
        ]
        
        if !foundPlaceName {
            for pattern in addressPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let range = NSRange(content.startIndex..., in: content)
                    if regex.firstMatch(in: content, options: [], range: range) != nil {
                        return true
                    }
                }
            }
        }
        
        return foundPlaceName
    }
    
    // MARK: - Context-Aware Suggestions
    
    /// Get context-aware clip suggestions
    /// Performance target: < 10ms response time
    /// - Parameters:
    ///   - items: Available clipboard items
    ///   - limit: Maximum number of suggestions
    /// - Returns: Scored and ranked suggestions
    func getSuggestions(from items: [ClipboardItem], limit: Int = 5) -> [ClipboardSuggestion] {
        guard !items.isEmpty else { return [] }
        
        // Get current context
        let currentApp = contextAnalyzer.currentAppBundleId
        let appCategory = contextAnalyzer.getAppCategory(bundleId: currentApp)
        
        // Score each item
        var scoredItems: [(ClipboardItem, Double, String)] = items.map { item in
            let (score, reason) = calculateScore(item: item, appCategory: appCategory, currentApp: currentApp)
            return (item, score, reason)
        }
        
        // Sort by score descending
        scoredItems.sort { $0.1 > $1.1 }
        
        // Return top suggestions
        return scoredItems.prefix(limit).map { item, score, reason in
            ClipboardSuggestion(item: item, score: score, reason: reason)
        }
    }
    
    /// Calculate suggestion score for an item
    /// Weighting: recency (40%), frequency (30%), context match (30%)
    private func calculateScore(item: ClipboardItem, appCategory: ContextAnalyzer.AppCategory, currentApp: String?) -> (Double, String) {
        var score: Double = 0.0
        var reasons: [String] = []
        
        // Recency score (40%)
        let hoursSinceUse = Date().timeIntervalSince(item.timestamp) / 3600
        let recencyScore = max(0, 1.0 - (hoursSinceUse / 24.0)) * 0.4 // Decay over 24 hours
        score += recencyScore
        if recencyScore > 0.3 {
            reasons.append("Recently used")
        }
        
        // Frequency score (30%) - favorites get boost
        let frequencyScore: Double = item.isFavorite ? 0.3 : 0.15
        score += frequencyScore
        if item.isFavorite {
            reasons.append("Favorite")
        }
        
        // Context match score (30%)
        let itemCategory = categorize(item.content)
        let contextScore = calculateContextMatch(itemCategory: itemCategory, appCategory: appCategory)
        score += contextScore * 0.3
        if contextScore > 0.5 {
            reasons.append("Matches \(appCategory.rawValue) context")
        }
        
        let reason = reasons.isEmpty ? "Suggested clip" : reasons.joined(separator: ", ")
        return (score, reason)
    }
    
    /// Calculate how well a clipboard category matches the current app context
    private func calculateContextMatch(itemCategory: ClipboardCategory, appCategory: ContextAnalyzer.AppCategory) -> Double {
        switch (itemCategory, appCategory) {
        case (.code, .development):
            return 1.0
        case (.url, .browser):
            return 1.0
        case (.email, .email):
            return 1.0
        case (.markdown, .writing):
            return 0.8
        case (.code, .writing):
            return 0.3
        case (.plainText, _):
            return 0.5 // Plain text is moderately useful everywhere
        default:
            return 0.2
        }
    }
    
    // MARK: - Cache Management
    
    private func updateCacheOrder(_ key: String) {
        cacheOrder.removeAll { $0 == key }
        cacheOrder.append(key)
    }
    
    private func cacheCategory(_ key: String, category: ClipboardCategory) {
        // Evict if at capacity
        if categoryCache.count >= maxCacheSize {
            if let oldestKey = cacheOrder.first {
                categoryCache.removeValue(forKey: oldestKey)
                cacheOrder.removeFirst()
            }
        }
        
        categoryCache[key] = category
        cacheOrder.append(key)
    }
    
    /// Clear category cache
    func clearCache() {
        categoryCache.removeAll()
        cacheOrder.removeAll()
    }
    
    /// Get cache statistics
    var cacheSize: Int {
        categoryCache.count
    }
}

// MARK: - Batch Processing

extension AIClipboardEngine {
    /// Categorize multiple items efficiently
    /// - Parameter items: Items to categorize
    /// - Returns: Dictionary mapping item ID to category
    func categorizeBatch(_ items: [ClipboardItem]) -> [UUID: ClipboardCategory] {
        var results: [UUID: ClipboardCategory] = [:]
        
        for item in items {
            results[item.id] = categorize(item.content)
        }
        
        return results
    }
}
