//
//  ClipboardManager.swift
//  TrayMe
//

import SwiftUI
import AppKit
import Combine

class ClipboardManager: ObservableObject {
    @Published var items: [ClipboardItem] = []
    @Published var favorites: [ClipboardItem] = []
    @Published var searchText: String = ""
    
    private var pasteboard = NSPasteboard.general
    private var changeCount: Int = 0
    private var timer: Timer?
    
    // Settings reference (can be set externally)
    weak var appSettings: AppSettings?
    
    // Legacy settings (still used if appSettings not set)
    var maxHistorySize: Int = 100
    var ignorePasswordManagers: Bool = true
    private let legacyPasswordManagerBundleIds = [
        "com.agilebits.onepassword",
        "com.agilebits.onepassword7",
        "com.1password.1password",
        "com.lastpass.LastPass",
        "com.bitwarden.desktop",
        "com.dashlane.Dashlane"
    ]
    
    init() {
        loadFromDisk()
        startMonitoring()
    }
    
    func startMonitoring() {
        changeCount = pasteboard.changeCount
        
        // Poll clipboard every 0.5 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkForChanges() {
        guard pasteboard.changeCount != changeCount else { return }
        changeCount = pasteboard.changeCount
        
        // Check if we should ignore this clipboard change based on source app
        if shouldIgnoreCurrentApp() {
            return
        }
        
        // Get clipboard content
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            addItem(content: string, sourceApp: getFrontmostAppBundleId())
        }
    }
    
    /// Get the bundle ID of the frontmost application
    private func getFrontmostAppBundleId() -> String? {
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
    
    /// Check if clipboard changes from the current frontmost app should be ignored
    private func shouldIgnoreCurrentApp() -> Bool {
        guard let bundleId = getFrontmostAppBundleId() else { return false }
        
        // Check app settings first (preferred)
        if let settings = appSettings {
            // Check if password manager filtering is enabled and app is in excluded list
            if settings.ignorePasswordManagers && settings.isAppExcluded(bundleId: bundleId) {
                return true
            }
            // Also check the custom exclusion list
            if settings.excludedAppBundleIds.contains(bundleId) {
                return true
            }
            return false
        }
        
        // Fallback to legacy behavior
        if ignorePasswordManagers && legacyPasswordManagerBundleIds.contains(bundleId) {
            return true
        }
        
        return false
    }
    
    func addItem(content: String, sourceApp: String? = nil) {
        // Don't add duplicates of the most recent item
        if let lastItem = items.first, lastItem.content == content {
            return
        }
        
        // Determine clipboard type and category
        let type = determineType(content: content)
        let category = ClipboardCategory.detect(from: content)
        let newItem = ClipboardItem(content: content, type: type, category: category, sourceApp: sourceApp)
        
        DispatchQueue.main.async {
            self.items.insert(newItem, at: 0)
            
            // Limit history size
            let maxSize = self.appSettings?.clipboardMaxHistory ?? self.maxHistorySize
            if self.items.count > maxSize {
                self.items = Array(self.items.prefix(maxSize))
            }
            
            self.saveToDisk()
        }
    }
    
    private func determineType(content: String) -> ClipboardItem.ClipboardType {
        // Check if URL
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue),
           let match = detector.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
           match.range.length == content.count {
            return .url
        }
        
        // Check if code (simple heuristic)
        if content.contains("{") || content.contains("function") || content.contains("class ") || content.contains("import ") {
            return .code
        }
        
        return .text
    }
    
    func copyToClipboard(_ item: ClipboardItem) {
        pasteboard.clearContents()
        pasteboard.setString(item.content, forType: .string)
        changeCount = pasteboard.changeCount
    }
    
    func toggleFavorite(_ item: ClipboardItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isFavorite.toggle()
            
            if items[index].isFavorite {
                favorites.append(items[index])
            } else {
                favorites.removeAll { $0.id == item.id }
            }
            
            saveToDisk()
        }
    }
    
    func deleteItem(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        favorites.removeAll { $0.id == item.id }
        saveToDisk()
    }
    
    func updateItemContent(_ item: ClipboardItem, newContent: String) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            let type = determineType(content: newContent)
            let category = ClipboardCategory.detect(from: newContent)
            items[index] = ClipboardItem(id: item.id, content: newContent, type: type, category: category, date: item.timestamp, isFavorite: item.isFavorite, sourceApp: item.sourceApp)
            
            // Update in favorites as well if it exists
            if let favIndex = favorites.firstIndex(where: { $0.id == item.id }) {
                favorites[favIndex] = items[index]
            }
            
            saveToDisk()
        }
    }
    
    func clearHistory() {
        // Remove only non-favorite items
        items.removeAll { !$0.isFavorite }
        saveToDisk()
    }
    
    var filteredItems: [ClipboardItem] {
        if searchText.isEmpty {
            return items
        }
        
        // Check if query looks like natural language (contains date/app/type keywords)
        let naturalLanguageIndicators = ["yesterday", "today", "last", "from", "in", "link", "url", "email", "code", "week", "month", "ago"]
        let isNaturalLanguageQuery = naturalLanguageIndicators.contains { searchText.lowercased().contains($0) }
        
        if isNaturalLanguageQuery {
            return SemanticSearchHelper.shared.search(items: items, query: searchText)
        }
        
        // Simple text search
        return items.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
    }
    
    /// Perform OCR on clipboard image and add extracted text
    func extractTextFromClipboardImage(completion: @escaping (Result<String, Error>) -> Void) {
        OCRManager.shared.recognizeTextFromClipboard { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let text):
                    // Add extracted text as a new clipboard item
                    self?.addItem(content: text, sourceApp: "OCR (Image)")
                    completion(.success(text))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Check if clipboard contains an image
    var hasImageInClipboard: Bool {
        return OCRManager.shared.hasImageInClipboard
    }
    
    // MARK: - Export Functions
    
    /// Export clipboard history to specified format
    func exportHistory(to url: URL, format: ExportFormat, dateRange: ClosedRange<Date>? = nil, includeOnlyFavorites: Bool = false, types: Set<ClipboardItem.ClipboardType>? = nil) throws {
        var itemsToExport = items
        
        // Filter by date range
        if let range = dateRange {
            itemsToExport = itemsToExport.filter { range.contains($0.timestamp) }
        }
        
        // Filter by favorites
        if includeOnlyFavorites {
            itemsToExport = itemsToExport.filter { $0.isFavorite }
        }
        
        // Filter by types
        if let types = types {
            itemsToExport = itemsToExport.filter { types.contains($0.type) }
        }
        
        let content: String
        switch format {
        case .csv:
            content = exportToCSV(items: itemsToExport)
        case .json:
            content = try exportToJSON(items: itemsToExport)
        case .txt:
            content = exportToTXT(items: itemsToExport)
        case .html:
            content = exportToHTML(items: itemsToExport)
        }
        
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    private func exportToCSV(items: [ClipboardItem]) -> String {
        var csv = "ID,Timestamp,Type,Category,Favorite,SourceApp,Content\n"
        let dateFormatter = ISO8601DateFormatter()
        
        for item in items {
            let escapedContent = item.content
                .replacingOccurrences(of: "\"", with: "\"\"")
                .replacingOccurrences(of: "\n", with: "\\n")
            let line = "\"\(item.id)\",\"\(dateFormatter.string(from: item.timestamp))\",\"\(item.type.rawValue)\",\"\(item.category.rawValue)\",\"\(item.isFavorite)\",\"\(item.sourceApp ?? "")\",\"\(escapedContent)\"\n"
            csv += line
        }
        
        return csv
    }
    
    private func exportToJSON(items: [ClipboardItem]) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(items)
        return String(data: data, encoding: .utf8) ?? "[]"
    }
    
    private func exportToTXT(items: [ClipboardItem]) -> String {
        var txt = "TrayMe Clipboard History Export\n"
        txt += "================================\n\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        
        for (index, item) in items.enumerated() {
            txt += "[\(index + 1)] \(dateFormatter.string(from: item.timestamp))\n"
            txt += "Type: \(item.type.rawValue) | Category: \(item.category.rawValue)"
            if item.isFavorite { txt += " ⭐" }
            txt += "\n"
            txt += "---\n"
            txt += item.content
            txt += "\n\n"
        }
        
        return txt
    }
    
    private func exportToHTML(items: [ClipboardItem]) -> String {
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>TrayMe Clipboard History</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
                .item { border: 1px solid #ddd; border-radius: 8px; padding: 12px; margin-bottom: 12px; }
                .meta { color: #666; font-size: 12px; margin-bottom: 8px; }
                .content { white-space: pre-wrap; font-family: monospace; background: #f5f5f5; padding: 8px; border-radius: 4px; }
                .favorite { border-left: 3px solid gold; }
                .badge { display: inline-block; padding: 2px 6px; border-radius: 4px; font-size: 10px; margin-right: 4px; }
                .url { background: #e3f2fd; }
                .code { background: #f3e5f5; }
                .text { background: #e8f5e9; }
            </style>
        </head>
        <body>
            <h1>TrayMe Clipboard History</h1>
            <p>Exported \(items.count) items</p>
        """
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        
        for item in items {
            let favoriteClass = item.isFavorite ? " favorite" : ""
            let escapedContent = item.content
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            
            html += """
            <div class="item\(favoriteClass)">
                <div class="meta">
                    <span class="badge \(item.type.rawValue)">\(item.type.rawValue.uppercased())</span>
                    <span class="badge">\(item.category.rawValue)</span>
                    \(dateFormatter.string(from: item.timestamp))
                    \(item.isFavorite ? "⭐" : "")
                </div>
                <div class="content">\(escapedContent)</div>
            </div>
            """
        }
        
        html += """
        </body>
        </html>
        """
        
        return html
    }
    
    // MARK: - Persistence
    
    private var saveURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("TrayMe", isDirectory: true)
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        return appFolder.appendingPathComponent("clipboard.json")
    }
    
    func saveToDisk() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(items) {
            try? data.write(to: saveURL)
        }
    }
    
    func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: saveURL.path) else { return }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        if let data = try? Data(contentsOf: saveURL),
           let decoded = try? decoder.decode([ClipboardItem].self, from: data) {
            self.items = decoded
            self.favorites = decoded.filter { $0.isFavorite }
        }
    }
    
    deinit {
        stopMonitoring()
    }
}

/// Export format options
enum ExportFormat: String, CaseIterable {
    case csv = "CSV"
    case json = "JSON"
    case txt = "Plain Text"
    case html = "HTML"
    
    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .json: return "json"
        case .txt: return "txt"
        case .html: return "html"
        }
    }
}
