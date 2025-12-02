//
//  SemanticSearchHelper.swift
//  TrayMe
//
//  Semantic search functionality with natural language query support

import Foundation
import NaturalLanguage

/// Helper for semantic search functionality
class SemanticSearchHelper {
    
    /// Singleton instance
    static let shared = SemanticSearchHelper()
    
    private let dateFormatter = DateFormatter()
    private let relativeDateFormatter = RelativeDateTimeFormatter()
    
    private init() {
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
    }
    
    /// Parse a natural language search query
    /// - Parameter query: Natural language query string
    /// - Returns: Parsed search parameters
    func parseQuery(_ query: String) -> SearchParameters {
        var params = SearchParameters()
        
        // Tokenize the query
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        tagger.string = query.lowercased()
        
        // Extract date-related terms
        params.dateRange = extractDateRange(from: query)
        
        // Extract app names
        params.sourceApp = extractSourceApp(from: query)
        
        // Extract content type hints
        params.contentTypes = extractContentTypes(from: query)
        
        // Extract keywords (remaining content after removing date/app terms)
        params.keywords = extractKeywords(from: query, excludingDate: params.dateRange != nil, excludingApp: params.sourceApp != nil)
        
        return params
    }
    
    /// Search clipboard items with natural language
    func search(items: [ClipboardItem], query: String) -> [ClipboardItem] {
        let params = parseQuery(query)
        
        return items.filter { item in
            // Date filter
            if let dateRange = params.dateRange {
                guard dateRange.contains(item.timestamp) else { return false }
            }
            
            // Source app filter
            if let sourceApp = params.sourceApp {
                guard let itemSourceApp = item.sourceApp?.lowercased(),
                      itemSourceApp.contains(sourceApp.lowercased()) else {
                    return false
                }
            }
            
            // Content type filter
            if !params.contentTypes.isEmpty {
                guard params.contentTypes.contains(item.category) else { return false }
            }
            
            // Keyword search
            if !params.keywords.isEmpty {
                let content = item.content.lowercased()
                let matchesAllKeywords = params.keywords.allSatisfy { keyword in
                    content.contains(keyword.lowercased())
                }
                guard matchesAllKeywords else { return false }
            }
            
            return true
        }
    }
    
    // MARK: - Private Helpers
    
    private func extractDateRange(from query: String) -> ClosedRange<Date>? {
        let lowercased = query.lowercased()
        let now = Date()
        let calendar = Calendar.current
        
        // Yesterday
        if lowercased.contains("yesterday") {
            guard let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)),
                  let endOfYesterday = calendar.date(byAdding: .second, value: -1, to: calendar.startOfDay(for: now)) else {
                return nil
            }
            return startOfYesterday...endOfYesterday
        }
        
        // Today
        if lowercased.contains("today") {
            let startOfToday = calendar.startOfDay(for: now)
            return startOfToday...now
        }
        
        // Last hour
        if lowercased.contains("last hour") || lowercased.contains("past hour") {
            guard let oneHourAgo = calendar.date(byAdding: .hour, value: -1, to: now) else {
                return nil
            }
            return oneHourAgo...now
        }
        
        // Last week
        if lowercased.contains("last week") || lowercased.contains("past week") || lowercased.contains("this week") {
            guard let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: now) else {
                return nil
            }
            return oneWeekAgo...now
        }
        
        // Last month
        if lowercased.contains("last month") || lowercased.contains("past month") || lowercased.contains("this month") {
            guard let oneMonthAgo = calendar.date(byAdding: .month, value: -1, to: now) else {
                return nil
            }
            return oneMonthAgo...now
        }
        
        // X days ago
        if let match = lowercased.range(of: #"(\d+)\s*days?\s*ago"#, options: .regularExpression) {
            let matchString = String(lowercased[match])
            if let daysString = matchString.split(separator: " ").first,
               let days = Int(daysString),
               let startDate = calendar.date(byAdding: .day, value: -days, to: now) {
                return startDate...now
            }
        }
        
        // X hours ago
        if let match = lowercased.range(of: #"(\d+)\s*hours?\s*ago"#, options: .regularExpression) {
            let matchString = String(lowercased[match])
            if let hoursString = matchString.split(separator: " ").first,
               let hours = Int(hoursString),
               let startDate = calendar.date(byAdding: .hour, value: -hours, to: now) {
                return startDate...now
            }
        }
        
        return nil
    }
    
    private func extractSourceApp(from query: String) -> String? {
        let lowercased = query.lowercased()
        
        // Common patterns: "from Slack", "in Safari", "copied from Chrome"
        let patterns = [
            #"from\s+(\w+)"#,
            #"in\s+(\w+)"#,
            #"copied\s+from\s+(\w+)"#,
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: lowercased, options: [], range: NSRange(lowercased.startIndex..., in: lowercased)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: lowercased) {
                let appName = String(lowercased[range])
                // Filter out date-related words
                let dateWords = ["yesterday", "today", "week", "month", "hour", "day", "ago"]
                if !dateWords.contains(appName) {
                    return appName
                }
            }
        }
        
        return nil
    }
    
    private func extractContentTypes(from query: String) -> Set<ClipboardCategory> {
        let lowercased = query.lowercased()
        var types = Set<ClipboardCategory>()
        
        // Map keywords to content types
        let typeKeywords: [String: ClipboardCategory] = [
            "link": .url,
            "url": .url,
            "website": .url,
            "email": .email,
            "phone": .phone,
            "number": .phone,
            "code": .code,
            "snippet": .code,
            "json": .json,
            "address": .address,
            "image": .image,
            "picture": .image,
            "file": .file,
        ]
        
        for (keyword, type) in typeKeywords {
            if lowercased.contains(keyword) {
                types.insert(type)
            }
        }
        
        return types
    }
    
    private func extractKeywords(from query: String, excludingDate: Bool, excludingApp: Bool) -> [String] {
        var cleaned = query.lowercased()
        
        // Remove date-related phrases
        if excludingDate {
            let datePatterns = [
                "yesterday", "today", "last hour", "past hour",
                "last week", "past week", "this week",
                "last month", "past month", "this month",
                #"\d+\s*days?\s*ago"#,
                #"\d+\s*hours?\s*ago"#,
            ]
            for pattern in datePatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: "")
                }
            }
        }
        
        // Remove app-related phrases
        if excludingApp {
            let appPatterns = [
                #"from\s+\w+"#,
                #"in\s+\w+"#,
                #"copied\s+from\s+\w+"#,
            ]
            for pattern in appPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: "")
                }
            }
        }
        
        // Remove type keywords
        let typeWords = ["link", "url", "website", "email", "phone", "number", "code", "snippet", "json", "address", "image", "picture", "file"]
        for word in typeWords {
            cleaned = cleaned.replacingOccurrences(of: word, with: "")
        }
        
        // Remove common words
        let stopWords = ["the", "a", "an", "that", "this", "those", "with", "about", "for", "and", "or", "but"]
        for word in stopWords {
            cleaned = cleaned.replacingOccurrences(of: "\\b\(word)\\b", with: "", options: .regularExpression)
        }
        
        // Split into keywords
        let keywords = cleaned.components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty && $0.count > 1 }
        
        return keywords
    }
}

/// Parsed search parameters
struct SearchParameters {
    var keywords: [String] = []
    var dateRange: ClosedRange<Date>?
    var sourceApp: String?
    var contentTypes: Set<ClipboardCategory> = []
}
