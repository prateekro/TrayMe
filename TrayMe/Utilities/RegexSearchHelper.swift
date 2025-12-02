//
//  RegexSearchHelper.swift
//  TrayMe
//
//  Regex search and replace functionality for clipboard history

import Foundation
import SwiftUI

/// Regex search helper for advanced clipboard searching
class RegexSearchHelper {
    
    /// Singleton instance
    static let shared = RegexSearchHelper()
    
    private init() {}
    
    /// Search clipboard items using regex pattern
    /// - Parameters:
    ///   - items: Items to search
    ///   - pattern: Regex pattern
    ///   - options: Regex options
    /// - Returns: Matching items with highlighted matches
    func search(items: [ClipboardItem], pattern: String, options: NSRegularExpression.Options = []) -> [RegexSearchResult] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return []
        }
        
        var results: [RegexSearchResult] = []
        
        for item in items {
            let range = NSRange(item.content.startIndex..., in: item.content)
            let matches = regex.matches(in: item.content, options: [], range: range)
            
            if !matches.isEmpty {
                let matchRanges = matches.compactMap { Range($0.range, in: item.content) }
                let matchStrings = matchRanges.map { String(item.content[$0]) }
                
                results.append(RegexSearchResult(
                    item: item,
                    pattern: pattern,
                    matches: matchStrings,
                    matchRanges: matchRanges
                ))
            }
        }
        
        return results
    }
    
    /// Find and replace in content using regex
    /// - Parameters:
    ///   - content: Original content
    ///   - pattern: Regex pattern to find
    ///   - replacement: Replacement template (supports capture groups like $1, $2)
    ///   - options: Regex options
    /// - Returns: Modified content
    func replace(in content: String, pattern: String, with replacement: String, options: NSRegularExpression.Options = []) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return nil
        }
        
        let range = NSRange(content.startIndex..., in: content)
        return regex.stringByReplacingMatches(in: content, options: [], range: range, withTemplate: replacement)
    }
    
    /// Preview replacements without applying
    /// - Parameters:
    ///   - content: Original content
    ///   - pattern: Regex pattern to find
    ///   - replacement: Replacement template
    ///   - options: Regex options
    /// - Returns: Preview result with before/after
    func previewReplace(in content: String, pattern: String, with replacement: String, options: NSRegularExpression.Options = []) -> ReplacePreview? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return nil
        }
        
        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, options: [], range: range)
        
        guard !matches.isEmpty else { return nil }
        
        let replaced = regex.stringByReplacingMatches(in: content, options: [], range: range, withTemplate: replacement)
        
        let matchDetails = matches.compactMap { match -> MatchDetail? in
            guard let matchRange = Range(match.range, in: content) else { return nil }
            let original = String(content[matchRange])
            
            // Calculate what this specific match would be replaced with
            let replacedMatch = regex.stringByReplacingMatches(
                in: original,
                options: [],
                range: NSRange(original.startIndex..., in: original),
                withTemplate: replacement
            )
            
            return MatchDetail(original: original, replaced: replacedMatch)
        }
        
        return ReplacePreview(
            original: content,
            replaced: replaced,
            matchCount: matches.count,
            matchDetails: matchDetails
        )
    }
    
    /// Validate if a regex pattern is valid
    func isValidPattern(_ pattern: String) -> Bool {
        do {
            _ = try NSRegularExpression(pattern: pattern, options: [])
            return true
        } catch {
            return false
        }
    }
    
    /// Common regex patterns for quick access
    static let commonPatterns: [SavedPattern] = [
        SavedPattern(name: "Email", pattern: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#, description: "Match email addresses"),
        SavedPattern(name: "URL", pattern: #"https?://[^\s<>\"{}|\\^`\[\]]+"#, description: "Match HTTP/HTTPS URLs"),
        SavedPattern(name: "Phone (US)", pattern: #"\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}"#, description: "Match US phone numbers"),
        SavedPattern(name: "IP Address", pattern: #"\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b"#, description: "Match IPv4 addresses"),
        SavedPattern(name: "Date (ISO)", pattern: #"\d{4}-\d{2}-\d{2}"#, description: "Match ISO date format"),
        SavedPattern(name: "Hex Color", pattern: #"#[0-9A-Fa-f]{6}\b"#, description: "Match hex color codes"),
        SavedPattern(name: "UUID", pattern: #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"#, description: "Match UUIDs"),
        SavedPattern(name: "Credit Card", pattern: #"\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b"#, description: "Match credit card numbers"),
    ]
}

/// Result of regex search
struct RegexSearchResult: Identifiable {
    let id = UUID()
    let item: ClipboardItem
    let pattern: String  // Original search pattern
    let matches: [String]
    let matchRanges: [Range<String.Index>]
    
    var matchCount: Int { matches.count }
}

/// Detail of a single match for replacement preview
struct MatchDetail {
    let original: String
    let replaced: String
}

/// Preview of regex replacement
struct ReplacePreview {
    let original: String
    let replaced: String
    let matchCount: Int
    let matchDetails: [MatchDetail]
}

/// Saved regex pattern
struct SavedPattern: Identifiable {
    let id = UUID()
    let name: String
    let pattern: String
    let description: String
}

/// SwiftUI view for regex search
struct RegexSearchView: View {
    @ObservedObject var clipboardManager: ClipboardManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchPattern = ""
    @State private var replacePattern = ""
    @State private var caseSensitive = false
    @State private var results: [RegexSearchResult] = []
    @State private var isValidRegex = true
    @State private var showReplace = false
    @State private var previewItem: ClipboardItem?
    @State private var replacePreview: ReplacePreview?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Regex Search")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()
            
            Divider()
            
            // Search input
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    TextField("Search pattern", text: $searchPattern)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: searchPattern) { _, _ in
                            validateAndSearch()
                        }
                    
                    Toggle("Aa", isOn: $caseSensitive)
                        .toggleStyle(.button)
                        .help("Case sensitive")
                        .onChange(of: caseSensitive) { _, _ in
                            validateAndSearch()
                        }
                }
                
                if !isValidRegex {
                    Text("Invalid regex pattern")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                // Common patterns
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(RegexSearchHelper.commonPatterns) { pattern in
                            Button(pattern.name) {
                                searchPattern = pattern.pattern
                                validateAndSearch()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help(pattern.description)
                        }
                    }
                }
                
                // Replace toggle
                Toggle("Find & Replace", isOn: $showReplace)
                
                if showReplace {
                    HStack {
                        TextField("Replace with (use $1, $2 for capture groups)", text: $replacePattern)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
            .padding()
            
            Divider()
            
            // Results
            if results.isEmpty && !searchPattern.isEmpty && isValidRegex {
                VStack {
                    Spacer()
                    Text("No matches found")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(results) { result in
                            RegexResultRow(
                                result: result,
                                showReplace: showReplace,
                                replacePattern: replacePattern,
                                onApplyReplace: { item, newContent in
                                    clipboardManager.updateItemContent(item, newContent: newContent)
                                    validateAndSearch()
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
            
            // Footer
            HStack {
                Text("\(results.count) items, \(results.reduce(0) { $0 + $1.matchCount }) matches")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        }
        .frame(width: 600, height: 500)
    }
    
    private func validateAndSearch() {
        isValidRegex = RegexSearchHelper.shared.isValidPattern(searchPattern)
        
        if isValidRegex && !searchPattern.isEmpty {
            let options: NSRegularExpression.Options = caseSensitive ? [] : [.caseInsensitive]
            results = RegexSearchHelper.shared.search(items: clipboardManager.items, pattern: searchPattern, options: options)
        } else {
            results = []
        }
    }
}

struct RegexResultRow: View {
    let result: RegexSearchResult
    let showReplace: Bool
    let replacePattern: String
    let onApplyReplace: (ClipboardItem, String) -> Void
    
    @State private var showPreview = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Item info
            HStack {
                CategoryBadge(category: result.item.category)
                Text(result.item.timeAgo)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(result.matchCount) match\(result.matchCount == 1 ? "" : "es")")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
            
            // Content with highlighted matches
            Text(highlightedContent)
                .font(.system(size: 12))
                .lineLimit(4)
            
            // Replace actions
            if showReplace && !replacePattern.isEmpty {
                HStack {
                    Button("Preview") {
                        showPreview = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("Apply") {
                        if let replaced = RegexSearchHelper.shared.replace(
                            in: result.item.content,
                            pattern: result.pattern,
                            with: replacePattern
                        ) {
                            onApplyReplace(result.item, replaced)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .sheet(isPresented: $showPreview) {
            if let preview = RegexSearchHelper.shared.previewReplace(
                in: result.item.content,
                pattern: result.pattern,
                with: replacePattern
            ) {
                ReplacePreviewSheet(preview: preview, onApply: {
                    onApplyReplace(result.item, preview.replaced)
                    showPreview = false
                }, onCancel: {
                    showPreview = false
                })
            }
        }
    }
    
    private var highlightedContent: AttributedString {
        var attributed = AttributedString(result.item.content)
        
        // Highlight matches
        for match in result.matches {
            if let range = attributed.range(of: match) {
                attributed[range].backgroundColor = .yellow.opacity(0.3)
                attributed[range].foregroundColor = .primary
            }
        }
        
        return attributed
    }
}

struct ReplacePreviewSheet: View {
    let preview: ReplacePreview
    let onApply: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Replace Preview")
                .font(.headline)
            
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Before")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ScrollView {
                        Text(preview.original)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 200)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(4)
                }
                
                VStack(alignment: .leading) {
                    Text("After")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ScrollView {
                        Text(preview.replaced)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 200)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(4)
                }
            }
            
            Text("\(preview.matchCount) replacement\(preview.matchCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Button("Cancel", action: onCancel)
                Spacer()
                Button("Apply Changes", action: onApply)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 500, height: 350)
    }
}
