//
//  SnippetManager.swift
//  TrayMe
//
//  Manager for text snippets with global keyboard monitoring

import Foundation
import AppKit
import Combine

/// Manager for text expansion snippets
@MainActor
class SnippetManager: ObservableObject {
    /// Shared instance
    static let shared = SnippetManager()
    
    /// All snippets
    @Published var snippets: [Snippet] = []
    
    /// All categories
    @Published var categories: [SnippetCategory] = SnippetCategory.defaultCategories
    
    /// Search text for filtering
    @Published var searchText: String = ""
    
    /// Currently selected snippet
    @Published var selectedSnippet: Snippet?
    
    /// Whether snippet expansion is enabled
    @Published var isEnabled: Bool = true {
        didSet {
            if isEnabled {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }
    
    /// Trigger matcher for efficient lookup
    let triggerMatcher = TriggerMatcher()
    
    /// Keyboard buffer for tracking typed text
    private let keyboardBuffer = KeyboardBuffer()
    
    /// Global event monitor
    private var eventMonitor: Any?
    
    /// Local event monitor
    private var localEventMonitor: Any?
    
    /// Persistence URL
    private var saveURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("TrayMe", isDirectory: true)
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        return appFolder.appendingPathComponent("snippets.json")
    }
    
    private var categoriesSaveURL: URL {
        saveURL.deletingLastPathComponent().appendingPathComponent("snippet_categories.json")
    }
    
    private init() {
        loadFromDisk()
        setupTriggerMatcher()
    }
    
    // MARK: - Public API
    
    /// Filtered snippets based on search text
    var filteredSnippets: [Snippet] {
        if searchText.isEmpty {
            return snippets
        }
        return snippets.filter {
            $0.trigger.localizedCaseInsensitiveContains(searchText) ||
            $0.expansion.localizedCaseInsensitiveContains(searchText) ||
            ($0.category?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    /// Snippets grouped by category
    var snippetsByCategory: [String: [Snippet]] {
        Dictionary(grouping: snippets) { $0.category ?? "Uncategorized" }
    }
    
    /// Create a new snippet
    @discardableResult
    func createSnippet(trigger: String, expansion: String, category: String? = nil) -> Snippet? {
        // Validate trigger
        guard isValidTrigger(trigger) else {
            return nil
        }
        
        // Check for conflicts
        if triggerMatcher.findConflict(for: trigger) != nil {
            return nil
        }
        
        let snippet = Snippet(
            trigger: trigger,
            expansion: expansion,
            category: category
        )
        
        snippets.append(snippet)
        triggerMatcher.add(snippet)
        saveToDisk()
        
        return snippet
    }
    
    /// Update a snippet
    func updateSnippet(_ snippet: Snippet) {
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            var updated = snippet
            updated.refreshVariables()
            snippets[index] = updated
            triggerMatcher.update(updated)
            saveToDisk()
        }
    }
    
    /// Delete a snippet
    func deleteSnippet(_ snippet: Snippet) {
        snippets.removeAll { $0.id == snippet.id }
        triggerMatcher.remove(snippet)
        
        if selectedSnippet?.id == snippet.id {
            selectedSnippet = snippets.first
        }
        
        saveToDisk()
    }
    
    /// Record snippet usage
    func recordUsage(_ snippet: Snippet) {
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[index].recordUsage()
            saveToDisk()
            
            // Track analytics
            Task {
                await AnalyticsManager.shared.track(.snippetUsed, metadata: [
                    "trigger": snippet.trigger,
                    "category": snippet.category ?? "none"
                ])
            }
        }
    }
    
    /// Validate a trigger string
    func isValidTrigger(_ trigger: String) -> Bool {
        // Must be at least 2 characters
        guard trigger.count >= 2 else { return false }
        
        // Must not contain spaces
        guard !trigger.contains(" ") else { return false }
        
        return true
    }
    
    /// Check if trigger would conflict
    func hasConflict(for trigger: String, excluding snippetId: UUID? = nil) -> Snippet? {
        let conflict = triggerMatcher.findConflict(for: trigger)
        if let conflict = conflict, conflict.id != snippetId {
            return conflict
        }
        return nil
    }
    
    /// Get most used snippets
    func getMostUsed(limit: Int = 10) -> [Snippet] {
        snippets.sorted { $0.usageCount > $1.usageCount }.prefix(limit).map { $0 }
    }
    
    /// Get recently used snippets
    func getRecentlyUsed(limit: Int = 10) -> [Snippet] {
        snippets.filter { $0.lastUsed != nil }
            .sorted { ($0.lastUsed ?? .distantPast) > ($1.lastUsed ?? .distantPast) }
            .prefix(limit)
            .map { $0 }
    }
    
    // MARK: - Category Management
    
    /// Add a category
    func addCategory(_ category: SnippetCategory) {
        if !categories.contains(where: { $0.name == category.name }) {
            categories.append(category)
            saveCategoriesToDisk()
        }
    }
    
    /// Remove a category
    func removeCategory(_ category: SnippetCategory) {
        categories.removeAll { $0.id == category.id }
        
        // Clear category from snippets
        for index in snippets.indices {
            if snippets[index].category == category.name {
                snippets[index].category = nil
            }
        }
        
        saveCategoriesToDisk()
        saveToDisk()
    }
    
    /// Rename a category
    func renameCategory(_ category: SnippetCategory, to newName: String) {
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            let oldName = categories[index].name
            categories[index].name = newName
            
            // Update snippets with this category
            for snippetIndex in snippets.indices {
                if snippets[snippetIndex].category == oldName {
                    snippets[snippetIndex].category = newName
                }
            }
            
            saveCategoriesToDisk()
            saveToDisk()
        }
    }
    
    // MARK: - Import/Export
    
    /// Export all snippets to JSON data
    func exportSnippets() -> Data? {
        Snippet.export(snippets: snippets, categories: categories)
    }
    
    /// Import snippets from JSON data
    func importSnippets(from data: Data, merge: Bool = true) -> Int {
        guard let (importedSnippets, importedCategories) = Snippet.importData(data) else {
            return 0
        }
        
        var importCount = 0
        
        // Import categories
        for category in importedCategories {
            if !categories.contains(where: { $0.name == category.name }) {
                categories.append(category)
            }
        }
        
        // Import snippets
        for var snippet in importedSnippets {
            // Check for trigger conflicts
            if let existing = snippets.first(where: { $0.trigger == snippet.trigger }) {
                if merge {
                    // Skip if trigger already exists
                    continue
                } else {
                    // Replace existing
                    deleteSnippet(existing)
                }
            }
            
            snippet = Snippet(
                id: UUID(), // New ID
                trigger: snippet.trigger,
                expansion: snippet.expansion,
                category: snippet.category,
                usageCount: 0,
                lastUsed: nil
            )
            
            snippets.append(snippet)
            triggerMatcher.add(snippet)
            importCount += 1
        }
        
        if importCount > 0 {
            saveCategoriesToDisk()
            saveToDisk()
        }
        
        return importCount
    }
    
    // MARK: - Keyboard Monitoring
    
    /// Start monitoring keyboard for trigger detection
    func startMonitoring() {
        guard isEnabled else { return }
        
        // Set up keyboard buffer callback
        keyboardBuffer.onPotentialMatch = { [weak self] buffer in
            self?.checkForTrigger(in: buffer)
        }
        
        // Global monitor for background detection
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        
        // Local monitor for when app is focused
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }
    }
    
    /// Stop monitoring keyboard
    func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        
        keyboardBuffer.clear()
    }
    
    // MARK: - Private Methods
    
    private func setupTriggerMatcher() {
        triggerMatcher.build(from: snippets)
    }
    
    private func handleKeyEvent(_ event: NSEvent) {
        // Handle special keys
        if event.keyCode == 51 { // Backspace
            keyboardBuffer.backspace()
            return
        }
        
        // Handle enter/return (clear buffer)
        if event.keyCode == 36 || event.keyCode == 76 {
            keyboardBuffer.clear()
            return
        }
        
        // Get typed character
        if let chars = event.characters {
            for char in chars {
                keyboardBuffer.append(char)
            }
        }
    }
    
    private func checkForTrigger(in buffer: String) {
        // Check all suffixes of the buffer for triggers
        for suffix in keyboardBuffer.suffixes {
            if let snippet = triggerMatcher.match(suffix) {
                expandSnippet(snippet, triggerLength: suffix.count)
                keyboardBuffer.clear()
                break
            }
        }
    }
    
    private func expandSnippet(_ snippet: Snippet, triggerLength: Int) {
        // Get expanded text
        let expansion = snippet.expand()
        
        // Delete the trigger characters
        for _ in 0..<triggerLength {
            simulateBackspace()
        }
        
        // Small delay for deletion to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            // Insert expanded text
            self.typeText(expansion)
            
            // Record usage
            self.recordUsage(snippet)
        }
    }
    
    private func simulateBackspace() {
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Key down
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: true) {
            keyDown.post(tap: .cghidEventTap)
        }
        
        // Key up
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: false) {
            keyUp.post(tap: .cghidEventTap)
        }
    }
    
    private func typeText(_ text: String) {
        // Use clipboard to paste text (faster and more reliable than simulating keystrokes)
        let pasteboard = NSPasteboard.general
        
        // Store the original change count to detect if clipboard was modified during paste
        let originalChangeCount = pasteboard.changeCount
        let originalContent = pasteboard.string(forType: .string)
        
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Simulate Cmd+V to paste
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Cmd down
        if let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 55, keyDown: true) {
            cmdDown.post(tap: .cghidEventTap)
        }
        
        // V down
        if let vDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true) {
            vDown.flags = .maskCommand
            vDown.post(tap: .cghidEventTap)
        }
        
        // V up
        if let vUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) {
            vUp.flags = .maskCommand
            vUp.post(tap: .cghidEventTap)
        }
        
        // Cmd up
        if let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 55, keyDown: false) {
            cmdUp.post(tap: .cghidEventTap)
        }
        
        // Restore original clipboard content after a delay, but only if clipboard
        // hasn't been modified by the user in the meantime
        if let original = originalContent {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                // Check if clipboard changed since we started (user might have copied something new)
                // We add 1 to account for our own paste operation
                if pasteboard.changeCount <= originalChangeCount + 1 {
                    pasteboard.clearContents()
                    pasteboard.setString(original, forType: .string)
                }
                // If changeCount is higher, user copied something new, so don't restore
            }
        }
    }
    
    // MARK: - Persistence
    
    func saveToDisk() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        
        if let data = try? encoder.encode(snippets) {
            try? data.write(to: saveURL)
        }
    }
    
    func loadFromDisk() {
        // Load snippets
        if FileManager.default.fileExists(atPath: saveURL.path),
           let data = try? Data(contentsOf: saveURL) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            if let decoded = try? decoder.decode([Snippet].self, from: data) {
                snippets = decoded
                if let first = snippets.first {
                    selectedSnippet = first
                }
            }
        }
        
        // Load categories
        if FileManager.default.fileExists(atPath: categoriesSaveURL.path),
           let data = try? Data(contentsOf: categoriesSaveURL) {
            let decoder = JSONDecoder()
            
            if let decoded = try? decoder.decode([SnippetCategory].self, from: data) {
                categories = decoded
            }
        }
    }
    
    func saveCategoriesToDisk() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        
        if let data = try? encoder.encode(categories) {
            try? data.write(to: categoriesSaveURL)
        }
    }
    
    deinit {
        stopMonitoring()
    }
}
