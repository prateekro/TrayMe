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
        
        // Determine clipboard type
        let type = determineType(content: content)
        let newItem = ClipboardItem(content: content, type: type)
        
        DispatchQueue.main.async {
            self.items.insert(newItem, at: 0)
            
            // Limit history size
            if self.items.count > self.maxHistorySize {
                self.items = Array(self.items.prefix(self.maxHistorySize))
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
