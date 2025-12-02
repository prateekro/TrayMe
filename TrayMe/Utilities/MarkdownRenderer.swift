//
//  MarkdownRenderer.swift
//  TrayMe
//
//  Markdown rendering utility using native AttributedString

import SwiftUI
import Foundation

/// View mode options for the notes editor
enum NoteViewMode: String, CaseIterable {
    case edit = "Edit"
    case preview = "Preview"
    case split = "Split"
    
    var icon: String {
        switch self {
        case .edit: return "pencil"
        case .preview: return "eye"
        case .split: return "rectangle.split.2x1"
        }
    }
}

/// Markdown renderer using native Swift AttributedString
struct MarkdownRenderer {
    
    /// Parse markdown content into AttributedString
    /// - Parameter content: The raw markdown string
    /// - Returns: Rendered AttributedString with formatting
    static func render(_ content: String) -> AttributedString {
        // Handle empty content
        guard !content.isEmpty else {
            return AttributedString("")
        }
        
        do {
            // Use native AttributedString markdown parsing
            var attributedString = try AttributedString(markdown: content, options: .init(
                allowsExtendedAttributes: true,
                interpretedSyntax: .inlineOnlyPreservingWhitespace,
                failurePolicy: .returnPartiallyParsedIfPossible
            ))
            
            // Apply default styling
            attributedString.font = .system(size: 14)
            
            return attributedString
        } catch {
            // Fall back to plain text on parse error
            return AttributedString(content)
        }
    }
    
    /// Parse markdown with full block-level support (headers, code blocks, etc.)
    /// - Parameter content: The raw markdown string
    /// - Returns: Rendered AttributedString with full formatting
    static func renderFull(_ content: String) -> AttributedString {
        guard !content.isEmpty else {
            return AttributedString("")
        }
        
        // Process line by line for block-level elements
        let lines = content.components(separatedBy: "\n")
        var result = AttributedString()
        var inCodeBlock = false
        var codeBlockContent = ""
        var codeBlockLanguage = ""
        
        for (index, line) in lines.enumerated() {
            // Handle code blocks
            if line.hasPrefix("```") {
                if inCodeBlock {
                    // End of code block
                    inCodeBlock = false
                    let codeString = renderCodeBlock(codeBlockContent, language: codeBlockLanguage)
                    result.append(codeString)
                    codeBlockContent = ""
                    codeBlockLanguage = ""
                } else {
                    // Start of code block
                    inCodeBlock = true
                    codeBlockLanguage = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                }
                continue
            }
            
            if inCodeBlock {
                if !codeBlockContent.isEmpty {
                    codeBlockContent += "\n"
                }
                codeBlockContent += line
                continue
            }
            
            // Process regular lines
            var processedLine = renderLine(line)
            
            // Add newline between lines (except for the last line)
            if index < lines.count - 1 {
                processedLine.append(AttributedString("\n"))
            }
            
            result.append(processedLine)
        }
        
        // Handle unclosed code block
        if inCodeBlock {
            let codeString = renderCodeBlock(codeBlockContent, language: codeBlockLanguage)
            result.append(codeString)
        }
        
        return result
    }
    
    /// Render a single line with appropriate formatting
    private static func renderLine(_ line: String) -> AttributedString {
        // Headers
        if line.hasPrefix("######") {
            return renderHeader(String(line.dropFirst(6).trimmingCharacters(in: .whitespaces)), level: 6)
        } else if line.hasPrefix("#####") {
            return renderHeader(String(line.dropFirst(5).trimmingCharacters(in: .whitespaces)), level: 5)
        } else if line.hasPrefix("####") {
            return renderHeader(String(line.dropFirst(4).trimmingCharacters(in: .whitespaces)), level: 4)
        } else if line.hasPrefix("###") {
            return renderHeader(String(line.dropFirst(3).trimmingCharacters(in: .whitespaces)), level: 3)
        } else if line.hasPrefix("##") {
            return renderHeader(String(line.dropFirst(2).trimmingCharacters(in: .whitespaces)), level: 2)
        } else if line.hasPrefix("#") {
            return renderHeader(String(line.dropFirst(1).trimmingCharacters(in: .whitespaces)), level: 1)
        }
        
        // Blockquote
        if line.hasPrefix(">") {
            return renderBlockquote(String(line.dropFirst(1).trimmingCharacters(in: .whitespaces)))
        }
        
        // Unordered list items
        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
            return renderListItem(String(line.dropFirst(2)), ordered: false, number: 0)
        }
        
        // Ordered list items
        if let match = line.firstMatch(of: /^(\d+)\.\s+(.*)/) {
            if let number = Int(match.1) {
                return renderListItem(String(match.2), ordered: true, number: number)
            }
        }
        
        // Horizontal rule
        if line == "---" || line == "***" || line == "___" {
            return renderHorizontalRule()
        }
        
        // Regular paragraph with inline formatting
        return renderInlineFormatting(line)
    }
    
    /// Render a header with appropriate size
    private static func renderHeader(_ text: String, level: Int) -> AttributedString {
        let sizes: [Int: CGFloat] = [1: 28, 2: 24, 3: 20, 4: 18, 5: 16, 6: 14]
        let size = sizes[level] ?? 14
        
        var result = renderInlineFormatting(text)
        result.font = .system(size: size, weight: .bold)
        result.foregroundColor = .primary
        
        return result
    }
    
    /// Render a blockquote
    private static func renderBlockquote(_ text: String) -> AttributedString {
        var result = AttributedString("│ ")
        result.foregroundColor = .secondary
        
        var content = renderInlineFormatting(text)
        content.foregroundColor = .secondary
        result.append(content)
        
        return result
    }
    
    /// Render a list item
    private static func renderListItem(_ text: String, ordered: Bool, number: Int) -> AttributedString {
        let bullet = ordered ? "\(number). " : "• "
        var result = AttributedString(bullet)
        result.foregroundColor = .accentColor
        
        result.append(renderInlineFormatting(text))
        
        return result
    }
    
    /// Render a horizontal rule
    private static func renderHorizontalRule() -> AttributedString {
        var result = AttributedString("────────────────────────────────")
        result.foregroundColor = .secondary
        return result
    }
    
    /// Render a code block
    private static func renderCodeBlock(_ content: String, language: String) -> AttributedString {
        var result = AttributedString()
        
        // Language label
        if !language.isEmpty {
            var langLabel = AttributedString("[\(language)]\n")
            langLabel.foregroundColor = .secondary
            langLabel.font = .system(size: 11, weight: .medium)
            result.append(langLabel)
        }
        
        // Code content
        var codeContent = AttributedString(content)
        codeContent.font = .system(size: 13, design: .monospaced)
        codeContent.foregroundColor = Color(nsColor: .systemPurple)
        codeContent.backgroundColor = Color(nsColor: .controlBackgroundColor)
        result.append(codeContent)
        result.append(AttributedString("\n"))
        
        return result
    }
    
    /// Apply inline formatting (bold, italic, code, links, strikethrough)
    private static func renderInlineFormatting(_ text: String) -> AttributedString {
        // Try native markdown parsing for inline elements
        do {
            let options = AttributedString.MarkdownParsingOptions(
                allowsExtendedAttributes: true,
                interpretedSyntax: .inlineOnlyPreservingWhitespace,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
            var result = try AttributedString(markdown: text, options: options)
            result.font = .system(size: 14)
            return result
        } catch {
            return AttributedString(text)
        }
    }
}

/// A SwiftUI view that displays rendered markdown
struct MarkdownView: View {
    let content: String
    
    var body: some View {
        ScrollView {
            Text(MarkdownRenderer.renderFull(content))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
    }
}

/// Preview wrapper for markdown content
struct MarkdownPreviewView: View {
    let content: String
    
    var body: some View {
        MarkdownView(content: content)
            .background(Color(NSColor.textBackgroundColor))
    }
}
