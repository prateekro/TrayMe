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
    
    /// AI-categorized items cache
    @Published var categoryCache: [UUID: ClipboardCategory] = [:]
    
    /// Context-aware suggestions
    @Published var suggestions: [ClipboardSuggestion] = []
    
    private var pasteboard = NSPasteboard.general
    private var changeCount: Int = 0
    private var timer: Timer?
    
    /// Active categorization tasks to prevent premature deallocation
    private var activeCategorizationTasks: Set<Task<Void, Never>> = []
    
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
            print("⚠️ Clips limit reached: \(result.message)")
            return
        }
        
        // Determine clipboard type
        let type = determineType(content: content)
        let newItem = ClipboardItem(content: content, type: type)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
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
        // Store task reference to ensure it completes
        let categorizationTask = Task.detached(priority: .utility) { [weak self, itemId = newItem.id] in
            guard let self = self else { return }
            let category = await MainActor.run { self.aiEngine.categorize(content) }
            
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.categoryCache[itemId] = category
            }
            
            // Track analytics in background
            await AnalyticsManager.shared.trackClipboardCopy(category: category.rawValue)
        }
        
        // Store task to prevent premature deallocation
        self.activeCategorizationTasks.insert(categorizationTask)
        
        // Clean up completed task
        Task { @MainActor in
            _ = await categorizationTask.result
            self.activeCategorizationTasks.remove(categorizationTask)
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
    
    private var saveURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("❌ ClipboardManager: Failed to get Application Support directory")
            return nil
        }
        let appFolder = appSupport.appendingPathComponent("TrayMe", isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
            return appFolder.appendingPathComponent("clipboard.json")
        } catch {
            print("❌ ClipboardManager: Failed to create directory: \(error.localizedDescription)")
            return nil
        }
    }
    
    func saveToDisk() {
        guard let saveURL = saveURL else {
            print("❌ ClipboardManager: Cannot save - invalid save URL")
            return
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(items)
            try data.write(to: saveURL, options: [.atomic])
            print("✅ ClipboardManager: Saved \(items.count) items")
        } catch {
            print("❌ ClipboardManager: Failed to save clipboard: \(error.localizedDescription)")
        }
    }
    
    func loadFromDisk() {
        guard let saveURL = saveURL else {
            print("❌ ClipboardManager: Cannot load - invalid save URL")
            return
        }
        
        guard FileManager.default.fileExists(atPath: saveURL.path) else { 
            print("📋 ClipboardManager: No saved clipboard file found")
            return 
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let data = try Data(contentsOf: saveURL)
            let decoded = try decoder.decode([ClipboardItem].self, from: data)
            self.items = decoded
            self.favorites = decoded.filter { $0.isFavorite }
            print("✅ ClipboardManager: Loaded \(decoded.count) items")
        } catch {
            print("❌ ClipboardManager: Failed to load clipboard: \(error.localizedDescription)")
            // Keep existing items if decode fails (safer than clearing)
        }
    }
    
    deinit {
        stopMonitoring()
    }
}
