//
//  SensitiveDataDetector.swift
//  TrayMe
//
//  Detect sensitive data patterns in text

import Foundation

/// Types of sensitive data
enum SensitiveDataType: String, CaseIterable {
    case apiKey = "API Key"
    case password = "Password"
    case creditCard = "Credit Card"
    case ssn = "SSN"
    case privateKey = "Private Key"
    case awsKey = "AWS Key"
    case jwtToken = "JWT Token"
    case githubToken = "GitHub Token"
    case slackToken = "Slack Token"
    case emailPassword = "Email Password"
    case databaseCredential = "Database Credential"
    case ipAddress = "IP Address"
    case bearerToken = "Bearer Token"
    
    var icon: String {
        switch self {
        case .apiKey, .awsKey:
            return "key.fill"
        case .password, .emailPassword:
            return "lock.fill"
        case .creditCard:
            return "creditcard.fill"
        case .ssn:
            return "person.text.rectangle"
        case .privateKey:
            return "lock.shield.fill"
        case .jwtToken, .bearerToken:
            return "checkmark.seal.fill"
        case .githubToken:
            return "chevron.left.forwardslash.chevron.right"
        case .slackToken:
            return "bubble.left.and.bubble.right.fill"
        case .databaseCredential:
            return "externaldrive.fill"
        case .ipAddress:
            return "network"
        }
    }
    
    var severity: Severity {
        switch self {
        case .privateKey, .awsKey, .databaseCredential:
            return .critical
        case .apiKey, .password, .creditCard, .ssn, .githubToken, .bearerToken:
            return .high
        case .jwtToken, .slackToken, .emailPassword:
            return .medium
        case .ipAddress:
            return .low
        }
    }
    
    enum Severity: String {
        case critical = "Critical"
        case high = "High"
        case medium = "Medium"
        case low = "Low"
        
        var color: String {
            switch self {
            case .critical: return "red"
            case .high: return "orange"
            case .medium: return "yellow"
            case .low: return "blue"
            }
        }
    }
}

/// Detector for sensitive data patterns
class SensitiveDataDetector: ObservableObject {
    /// Compiled regex patterns for performance
    private var compiledPatterns: [(SensitiveDataType, NSRegularExpression)] = []
    
    /// Detection patterns
    private let patterns: [(SensitiveDataType, String)] = [
        // API Keys (generic)
        (.apiKey, #"(?:api[_-]?key|apikey)[=:]\s*['\"]?([a-zA-Z0-9_\-]{20,})['\"]?"#),
        (.apiKey, #"^[a-zA-Z0-9_\-]{32,}$"#),
        
        // Passwords
        (.password, #"(?:password|passwd|pwd)[=:]\s*['\"]?([^\s'\"]{8,})['\"]?"#),
        (.password, #"(?:secret|token)[=:]\s*['\"]?([^\s'\"]{8,})['\"]?"#),
        
        // Credit Cards
        (.creditCard, #"(?:4[0-9]{12}(?:[0-9]{3})?)"#),  // Visa
        (.creditCard, #"(?:5[1-5][0-9]{14})"#),  // MasterCard
        (.creditCard, #"(?:3[47][0-9]{13})"#),  // American Express
        (.creditCard, #"(?:6(?:011|5[0-9]{2})[0-9]{12})"#),  // Discover
        
        // SSN
        (.ssn, #"\b\d{3}[-\s]?\d{2}[-\s]?\d{4}\b"#),
        
        // Private Keys
        (.privateKey, #"-----BEGIN (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----"#),
        (.privateKey, #"-----BEGIN PGP PRIVATE KEY BLOCK-----"#),
        
        // AWS Keys
        (.awsKey, #"AKIA[0-9A-Z]{16}"#),
        (.awsKey, #"(?:aws[_-]?secret[_-]?access[_-]?key)[=:]\s*['\"]?([a-zA-Z0-9/+=]{40})['\"]?"#),
        
        // JWT Tokens
        (.jwtToken, #"eyJ[a-zA-Z0-9_-]*\.eyJ[a-zA-Z0-9_-]*\.[a-zA-Z0-9_-]*"#),
        
        // GitHub Tokens
        (.githubToken, #"ghp_[a-zA-Z0-9]{36}"#),
        (.githubToken, #"gho_[a-zA-Z0-9]{36}"#),
        (.githubToken, #"github_pat_[a-zA-Z0-9]{22}_[a-zA-Z0-9]{59}"#),
        
        // Slack Tokens
        (.slackToken, #"xox[baprs]-[0-9]{10,13}-[0-9]{10,13}[a-zA-Z0-9-]*"#),
        
        // Database Credentials
        (.databaseCredential, #"(?:mysql|postgres|mongodb|redis)://[^\s]+"#),
        (.databaseCredential, #"(?:DB_PASSWORD|DATABASE_PASSWORD)[=:]\s*['\"]?([^\s'\"]+)['\"]?"#),
        
        // Bearer Tokens
        (.bearerToken, #"Bearer\s+[a-zA-Z0-9_\-\.]+\.[a-zA-Z0-9_\-\.]+\.[a-zA-Z0-9_\-\.]+"#),
        
        // IP Addresses (private ranges often indicate internal systems)
        (.ipAddress, #"\b(?:10\.\d{1,3}\.\d{1,3}\.\d{1,3}|172\.(?:1[6-9]|2[0-9]|3[0-1])\.\d{1,3}\.\d{1,3}|192\.168\.\d{1,3}\.\d{1,3})\b"#),
    ]
    
    init() {
        compilePatterns()
    }
    
    /// Compile patterns for performance
    private func compilePatterns() {
        compiledPatterns = patterns.compactMap { type, pattern in
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                return (type, regex)
            }
            return nil
        }
    }
    
    /// Detect sensitive data in text
    /// - Parameter text: Text to analyze
    /// - Returns: First detected sensitive data type, or nil
    func detect(_ text: String) -> SensitiveDataType? {
        let range = NSRange(text.startIndex..., in: text)
        
        for (type, regex) in compiledPatterns {
            if regex.firstMatch(in: text, options: [], range: range) != nil {
                return type
            }
        }
        
        return nil
    }
    
    /// Detect all sensitive data types in text
    /// - Parameter text: Text to analyze
    /// - Returns: Set of all detected sensitive data types
    func detectAll(_ text: String) -> Set<SensitiveDataType> {
        let range = NSRange(text.startIndex..., in: text)
        var found = Set<SensitiveDataType>()
        
        for (type, regex) in compiledPatterns {
            if regex.firstMatch(in: text, options: [], range: range) != nil {
                found.insert(type)
            }
        }
        
        return found
    }
    
    /// Get match locations for a specific type
    /// - Parameters:
    ///   - text: Text to analyze
    ///   - type: Sensitive data type to find
    /// - Returns: Array of ranges where matches were found
    func findMatches(_ text: String, for type: SensitiveDataType) -> [Range<String.Index>] {
        let range = NSRange(text.startIndex..., in: text)
        var matches: [Range<String.Index>] = []
        
        for (matchType, regex) in compiledPatterns where matchType == type {
            let results = regex.matches(in: text, options: [], range: range)
            
            for result in results {
                if let swiftRange = Range(result.range, in: text) {
                    matches.append(swiftRange)
                }
            }
        }
        
        return matches
    }
    
    /// Mask sensitive data in text
    /// - Parameter text: Text to mask
    /// - Returns: Text with sensitive data masked
    func mask(_ text: String) -> String {
        let types = detectAll(text)
        
        // Collect all match ranges with their lengths
        var matchRanges: [(range: Range<String.Index>, length: Int)] = []
        
        for type in types {
            let matches = findMatches(text, for: type)
            for match in matches {
                let length = text.distance(from: match.lowerBound, to: match.upperBound)
                matchRanges.append((match, length))
            }
        }
        
        // Sort by start position in descending order to process from end to beginning
        matchRanges.sort { text.distance(from: text.startIndex, to: $0.range.lowerBound) >
                          text.distance(from: text.startIndex, to: $1.range.lowerBound) }
        
        var result = text
        
        // Process matches from end to beginning to maintain valid indices
        for (range, length) in matchRanges {
            let masked = String(repeating: "•", count: min(length, 20))
            // Recalculate the range offset based on current result string
            let offset = text.distance(from: text.startIndex, to: range.lowerBound)
            let startIdx = result.index(result.startIndex, offsetBy: offset)
            let endIdx = result.index(startIdx, offsetBy: length)
            result.replaceSubrange(startIdx..<endIdx, with: masked)
        }
        
        return result
    }
    
    /// Check if text contains any sensitive data
    /// - Parameter text: Text to check
    /// - Returns: Whether text contains sensitive data
    func containsSensitiveData(_ text: String) -> Bool {
        detect(text) != nil
    }
    
    /// Get highest severity of detected data
    /// - Parameter text: Text to analyze
    /// - Returns: Highest severity found, or nil if no sensitive data
    func getHighestSeverity(_ text: String) -> SensitiveDataType.Severity? {
        let types = detectAll(text)
        
        if types.contains(where: { $0.severity == .critical }) {
            return .critical
        }
        if types.contains(where: { $0.severity == .high }) {
            return .high
        }
        if types.contains(where: { $0.severity == .medium }) {
            return .medium
        }
        if types.contains(where: { $0.severity == .low }) {
            return .low
        }
        
        return nil
    }
}
