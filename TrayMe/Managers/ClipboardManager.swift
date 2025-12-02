//
//  ClipboardManager.swift
//  TrayMe
//

import SwiftUI
import AppKit
import Combine
import os.log

/// Private logger for ClipboardManager
private let logger = Logger(subsystem: "com.trayme.TrayMe", category: "ClipboardManager")

class ClipboardManager: ObservableObject {
    @Published var items: [ClipboardItem] = []
    @Published var favorites: [ClipboardItem] = []
    @Published var searchText: String = ""
    
    /// AI-categorized items cache
    @Published var categoryCache: [UUID: ClipboardCategory] = [:]
    
    /// Context-aware suggestions
    @Published var suggestions: [ClipboardSuggestion] = []
    
    private var pasteboard = NSPasteboard.general
    private var changeCount: Int = 0
    private var timer: Timer?
    
    // Debounced save to prevent excessive disk writes
    private var saveWorkItem: DispatchWorkItem?
    private let saveDebounceInterval: TimeInterval = 0.5
    
    // AI Engine reference
    private var aiEngine: AIClipboardEngine { AIClipboardEngine.shared }
    
    // Settings
    var maxHistorySize: Int = 100
    var ignorePasswordManagers: Bool = true
    private let passwordManagerBundleIds = [
        "com.agilebits.onepassword",
        "com.lastpass.LastPass",
        "com.bitwarden.desktop",
        "com.dashlane.Dashlane"
    ]
    
    init() {
        loadFromDisk()
        startMonitoring()
        
        // Categorize existing items in background
        Task { @MainActor in
            await categorizeBatch()
        }
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
        
        // Check if we should ignore this clipboard change
        if ignorePasswordManagers && isFromPasswordManager() {
            return
        }
        
        // Get clipboard content
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            addItem(content: string)
        }
    }
    
    private func isFromPasswordManager() -> Bool {
        // Check if the frontmost app is a password manager
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontApp.bundleIdentifier else {
            return false
        }
        return passwordManagerBundleIds.contains(bundleId)
    }
    
    func addItem(content: String) {
        // Don't add duplicates of the most recent item
        if let lastItem = items.first, lastItem.content == content {
            return
        }
        
        // Check usage limits on main thread
        let checker = UsageLimitChecker()
        let result = checker.checkAddClip()
        guard result.isAllowed else {
            logger.warning("Clips limit reached: \(result.message)")
            return
        }
        
        // Determine clipboard type
        let type = determineType(content: content)
        let newItem = ClipboardItem(content: content, type: type)
        
        DispatchQueue.main.async {
            self.items.insert(newItem, at: 0)
            
            // Limit history size
            if self.items.count > self.maxHistorySize {
                self.items = Array(self.items.prefix(self.maxHistorySize))
            }
            
            // Update subscription usage on main thread
            Task { @MainActor in
                SubscriptionManager.shared.updateClipsCount(self.items.count)
            }
            
            // Update suggestions
            self.updateSuggestions()
            
            self.saveToDisk()
        }
        
        // AI categorization in background (non-blocking)
        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            let category = await MainActor.run { self.aiEngine.categorize(content) }
            
            await MainActor.run {
                self.categoryCache[newItem.id] = category
            }
            
            // Track analytics in background
            await AnalyticsManager.shared.trackClipboardCopy(category: category.rawValue)
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
            items[index] = ClipboardItem(id: item.id, content: newContent, type: type, date: item.timestamp, isFavorite: item.isFavorite)
            
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
        return items.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
    }
    
    // MARK: - AI Features
    
    /// Get category for an item
    func getCategory(for item: ClipboardItem) -> ClipboardCategory {
        if let cached = categoryCache[item.id] {
            return cached
        }
        let category = aiEngine.categorize(item.content)
        categoryCache[item.id] = category
        return category
    }
    
    /// Categorize all items in batch
    private func categorizeBatch() async {
        let categories = aiEngine.categorizeBatch(items)
        for (id, category) in categories {
            categoryCache[id] = category
        }
    }
    
    /// Update context-aware suggestions
    func updateSuggestions() {
        suggestions = aiEngine.getSuggestions(from: items, limit: 5)
    }
    
    /// Apply text transformation
    func applyTransformation(_ transformation: TextTransformation, to item: ClipboardItem) -> String {
        return aiEngine.textTransformer.transform(item.content, using: transformation)
    }
    
    /// Check if item contains sensitive data
    func isSensitive(_ item: ClipboardItem) -> Bool {
        return SecurityManager.shared.detectSensitiveContent(item.content) != nil
    }
    
    /// Get sensitive data type for item
    func getSensitiveType(_ item: ClipboardItem) -> SensitiveDataType? {
        return SecurityManager.shared.detectSensitiveContent(item.content)
    }
    
    // MARK: - Persistence
    
    private var saveURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("TrayMe", isDirectory: true)
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        return appFolder.appendingPathComponent("clipboard.json")
    }
    
    func saveToDisk() {
        // Cancel any pending save
        saveWorkItem?.cancel()
        
        // Create new debounced save task
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [] // Compact output for speed
            
            do {
                let data = try encoder.encode(self.items)
                try data.write(to: self.saveURL, options: .atomic)
                logger.debug("Clipboard saved successfully (\(self.items.count) items)")
            } catch {
                logger.error("Failed to save clipboard: \(error.localizedDescription)")
            }
        }
        
        saveWorkItem = workItem
        
        // Execute after debounce interval
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + saveDebounceInterval, execute: workItem)
    }
    
    func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: saveURL.path) else {
            logger.info("No clipboard history file found, starting fresh")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let data = try Data(contentsOf: saveURL)
            let decoded = try decoder.decode([ClipboardItem].self, from: data)
            self.items = decoded
            self.favorites = decoded.filter { $0.isFavorite }
            logger.debug("Loaded \(decoded.count) clipboard items from disk")
        } catch {
            logger.error("Failed to load clipboard history: \(error.localizedDescription)")
        }
    }
    
    deinit {
        // Cancel any pending debounced save
        saveWorkItem?.cancel()
        
        // Save immediately on deinit to ensure no data loss
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(items)
            try data.write(to: saveURL, options: .atomic)
            // Note: Can't use logger in deinit as it may have been deinitialized
        } catch {
            // Best effort save - can't log in deinit
            #if DEBUG
            print("ClipboardManager deinit: Failed to save clipboard - \(error.localizedDescription)")
            #endif
        }
        
        stopMonitoring()
    }
}
