//
//  ContextAnalyzer.swift
//  TrayMe
//
//  Context-aware analysis for intelligent clipboard suggestions

import Foundation
import AppKit

/// Context analyzer for app-aware clipboard suggestions
@MainActor
class ContextAnalyzer: ObservableObject {
    /// Shared instance
    static let shared = ContextAnalyzer()
    
    /// App categories for context matching
    enum AppCategory: String, CaseIterable {
        case development = "Development"
        case browser = "Browser"
        case email = "Email"
        case writing = "Writing"
        case design = "Design"
        case terminal = "Terminal"
        case spreadsheet = "Spreadsheet"
        case communication = "Communication"
        case other = "Other"
    }
    
    /// App bundle ID to category mapping
    private let appCategoryMap: [String: AppCategory] = [
        // Development
        "com.apple.dt.Xcode": .development,
        "com.microsoft.VSCode": .development,
        "com.jetbrains.intellij": .development,
        "com.jetbrains.pycharm": .development,
        "com.jetbrains.WebStorm": .development,
        "com.sublimetext.4": .development,
        "com.sublimetext.3": .development,
        "com.panic.Nova": .development,
        "com.barebones.bbedit": .development,
        "com.github.atom": .development,
        "com.googlecode.iterm2": .terminal,
        "com.apple.Terminal": .terminal,
        
        // Browsers
        "com.apple.Safari": .browser,
        "com.google.Chrome": .browser,
        "org.mozilla.firefox": .browser,
        "com.microsoft.Edge": .browser,
        "com.brave.Browser": .browser,
        "com.operasoftware.Opera": .browser,
        "com.vivaldi.Vivaldi": .browser,
        "company.thebrowser.Browser": .browser,  // Arc
        
        // Email
        "com.apple.mail": .email,
        "com.microsoft.Outlook": .email,
        "com.readdle.smartemail-Mac": .email,  // Spark
        "com.superhuman.Superhuman": .email,
        "com.freron.MailMate": .email,
        
        // Writing
        "com.apple.iWork.Pages": .writing,
        "com.microsoft.Word": .writing,
        "com.google.docs": .writing,
        "com.ulyssesapp.mac": .writing,
        "com.omnigroup.OmniOutliner5": .writing,
        "md.obsidian": .writing,
        "com.notion.id": .writing,
        "com.apple.Notes": .writing,
        "abnerworks.Typora": .writing,
        "net.ia.writer.mac": .writing,
        
        // Design
        "com.figma.Desktop": .design,
        "com.bohemiancoding.sketch3": .design,
        "com.adobe.Photoshop": .design,
        "com.adobe.Illustrator": .design,
        "com.adobe.InDesign": .design,
        "com.adobe.xd": .design,
        "com.pixelmator.x": .design,
        "com.affinity.designer2": .design,
        "com.affinity.photo2": .design,
        
        // Spreadsheet
        "com.apple.iWork.Numbers": .spreadsheet,
        "com.microsoft.Excel": .spreadsheet,
        "com.google.sheets": .spreadsheet,
        
        // Communication
        "com.tinyspeck.slackmacgap": .communication,
        "com.apple.iChat": .communication,
        "com.microsoft.teams": .communication,
        "us.zoom.xos": .communication,
        "com.discord.Discord": .communication,
        "ru.keepcoder.Telegram": .communication,
        "net.whatsapp.WhatsApp": .communication,
    ]
    
    /// Current frontmost app bundle identifier
    @Published private(set) var currentAppBundleId: String?
    
    /// Current app category
    @Published private(set) var currentCategory: AppCategory = .other
    
    /// App usage history for pattern detection
    private var appUsageHistory: [(bundleId: String, timestamp: Date)] = []
    private let maxHistorySize = 100
    
    /// Workspace notification observer
    private var workspaceObserver: Any?
    
    private init() {
        setupNotifications()
        updateCurrentApp()
    }
    
    // MARK: - Public API
    
    /// Get the category for an app bundle ID
    func getAppCategory(bundleId: String?) -> AppCategory {
        guard let bundleId = bundleId else {
            return .other
        }
        return appCategoryMap[bundleId] ?? .other
    }
    
    /// Get frequently used apps
    func getFrequentApps(limit: Int = 5) -> [(bundleId: String, count: Int)] {
        var counts: [String: Int] = [:]
        
        for entry in appUsageHistory {
            counts[entry.bundleId, default: 0] += 1
        }
        
        return counts.sorted { $0.value > $1.value }
            .prefix(limit)
            .map { ($0.key, $0.value) }
    }
    
    /// Get recently used apps
    func getRecentApps(limit: Int = 5) -> [String] {
        var seen = Set<String>()
        var recent: [String] = []
        
        for entry in appUsageHistory.reversed() {
            if !seen.contains(entry.bundleId) {
                seen.insert(entry.bundleId)
                recent.append(entry.bundleId)
                if recent.count >= limit {
                    break
                }
            }
        }
        
        return recent
    }
    
    /// Check if current context suggests code-related content
    var isCodeContext: Bool {
        currentCategory == .development || currentCategory == .terminal
    }
    
    /// Check if current context suggests text-related content
    var isTextContext: Bool {
        currentCategory == .writing || currentCategory == .email
    }
    
    /// Check if current context suggests URL-related content
    var isURLContext: Bool {
        currentCategory == .browser
    }
    
    // MARK: - Private Methods
    
    private func setupNotifications() {
        // Observe app activation changes
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppActivation(notification)
        }
    }
    
    private func handleAppActivation(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier else {
            return
        }
        
        currentAppBundleId = bundleId
        currentCategory = getAppCategory(bundleId: bundleId)
        
        // Track usage
        trackAppUsage(bundleId: bundleId)
    }
    
    private func updateCurrentApp() {
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           let bundleId = frontApp.bundleIdentifier {
            currentAppBundleId = bundleId
            currentCategory = getAppCategory(bundleId: bundleId)
        }
    }
    
    private func trackAppUsage(bundleId: String) {
        appUsageHistory.append((bundleId: bundleId, timestamp: Date()))
        
        // Limit history size
        if appUsageHistory.count > maxHistorySize {
            appUsageHistory.removeFirst()
        }
    }
    
    deinit {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}

// MARK: - Content Relevance Scoring

extension ContextAnalyzer {
    /// Calculate relevance score for content in current context
    /// - Parameters:
    ///   - category: Content category
    ///   - recentlyUsed: Whether content was recently used
    ///   - isFavorite: Whether content is favorited
    /// - Returns: Relevance score from 0.0 to 1.0
    func calculateRelevance(
        category: ClipboardCategory,
        recentlyUsed: Bool,
        isFavorite: Bool
    ) -> Double {
        var score = 0.0
        
        // Context match (40%)
        let contextScore = contextMatchScore(for: category)
        score += contextScore * 0.4
        
        // Recency bonus (30%)
        if recentlyUsed {
            score += 0.3
        }
        
        // Favorite bonus (30%)
        if isFavorite {
            score += 0.3
        }
        
        return min(1.0, score)
    }
    
    /// Get context match score for a content category
    private func contextMatchScore(for category: ClipboardCategory) -> Double {
        switch (currentCategory, category) {
        // Development context
        case (.development, .code):
            return 1.0
        case (.development, .json):
            return 0.9
        case (.development, .url):
            return 0.6
            
        // Terminal context
        case (.terminal, .code):
            return 0.9
        case (.terminal, .credential):
            return 0.7
            
        // Browser context
        case (.browser, .url):
            return 1.0
        case (.browser, .email):
            return 0.5
            
        // Email context
        case (.email, .email):
            return 1.0
        case (.email, .address):
            return 0.8
        case (.email, .phone):
            return 0.7
            
        // Writing context
        case (.writing, .plainText):
            return 0.9
        case (.writing, .markdown):
            return 1.0
            
        // Design context
        case (.design, .url):
            return 0.5
            
        // Communication context
        case (.communication, .url):
            return 0.7
        case (.communication, .email):
            return 0.6
            
        default:
            return 0.3 // Base score for any content
        }
    }
}

// MARK: - App Information

extension ContextAnalyzer {
    /// Get display name for an app
    static func getAppName(bundleId: String) -> String? {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return FileManager.default.displayName(atPath: url.path)
        }
        return nil
    }
    
    /// Get app icon for a bundle ID
    static func getAppIcon(bundleId: String) -> NSImage? {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return nil
    }
}
