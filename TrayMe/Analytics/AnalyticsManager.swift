//
//  AnalyticsManager.swift
//  TrayMe
//
//  Usage analytics tracking with privacy-first local storage

import Foundation
import Combine

/// Analytics event types
enum EventType: String, Codable {
    case clipboardCopy = "clipboard_copy"
    case clipboardPaste = "clipboard_paste"
    case snippetUsed = "snippet_used"
    case fileAdded = "file_added"
    case fileOpened = "file_opened"
    case noteCreated = "note_created"
    case noteEdited = "note_edited"
    case searchPerformed = "search_performed"
    case categoryViewed = "category_viewed"
    case transformationApplied = "transformation_applied"
    case appLaunched = "app_launched"
    case panelShown = "panel_shown"
    case panelHidden = "panel_hidden"
}

/// Analytics event model
struct AnalyticsEvent: Identifiable, Codable {
    let id: UUID
    let type: EventType
    let timestamp: Date
    let metadata: [String: String]
    
    init(type: EventType, metadata: [String: String] = [:]) {
        self.id = UUID()
        self.type = type
        self.timestamp = Date()
        self.metadata = metadata
    }
}

/// Daily aggregate statistics
struct DailyStats: Codable {
    let date: String
    var clipboardCopies: Int
    var clipboardPastes: Int
    var snippetsUsed: Int
    var filesAdded: Int
    var filesOpened: Int
    var notesCreated: Int
    var searchCount: Int
    var panelShows: Int
    
    static func empty(for date: String) -> DailyStats {
        DailyStats(
            date: date,
            clipboardCopies: 0,
            clipboardPastes: 0,
            snippetsUsed: 0,
            filesAdded: 0,
            filesOpened: 0,
            notesCreated: 0,
            searchCount: 0,
            panelShows: 0
        )
    }
}

/// Category distribution for statistics
struct CategoryStat: Identifiable, Codable {
    var id: String { category }
    let category: String
    var count: Int
    var lastUpdated: Date
}

/// Analytics manager - all data stays local
actor AnalyticsManager {
    /// Shared instance
    static let shared = AnalyticsManager()
    
    /// Database for analytics storage
    private var database: DatabaseManager { DatabaseManager.shared }
    
    /// Whether analytics is enabled
    private var isEnabled: Bool = true
    
    /// Cache for daily stats
    private var dailyStatsCache: [String: DailyStats] = [:]
    
    /// Date formatter for daily stats
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private init() {
        Task {
            await initializeDatabase()
        }
    }
    
    // MARK: - Configuration
    
    /// Enable or disable analytics
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }
    
    /// Check if analytics is enabled
    var analyticsEnabled: Bool {
        isEnabled
    }
    
    // MARK: - Event Tracking
    
    /// Track an analytics event
    /// - Parameters:
    ///   - type: Type of event
    ///   - metadata: Additional metadata for the event
    func track(_ type: EventType, metadata: [String: String] = [:]) async {
        guard isEnabled else { return }
        
        let event = AnalyticsEvent(type: type, metadata: metadata)
        
        do {
            try await database.open()
            
            // Store event
            let metadataJson = try? JSONEncoder().encode(metadata)
            let metadataString = metadataJson.flatMap { String(data: $0, encoding: .utf8) }
            
            try await database.execute(
                "INSERT INTO analytics_events (id, type, timestamp, metadata) VALUES (?, ?, ?, ?)",
                parameters: [event.id.uuidString, event.type.rawValue, event.timestamp, metadataString]
            )
            
            // Update daily aggregate
            await updateDailyAggregate(for: event)
            
        } catch {
            print("Analytics tracking failed: \(error)")
        }
    }
    
    /// Track clipboard copy event
    func trackClipboardCopy(category: String? = nil) async {
        var metadata: [String: String] = [:]
        if let category = category {
            metadata["category"] = category
        }
        await track(.clipboardCopy, metadata: metadata)
        
        // Update category stats
        if let category = category {
            await updateCategoryStat(category)
        }
    }
    
    /// Track clipboard paste event
    func trackClipboardPaste() async {
        await track(.clipboardPaste)
    }
    
    /// Track snippet usage
    func trackSnippetUsed(trigger: String) async {
        await track(.snippetUsed, metadata: ["trigger": trigger])
    }
    
    /// Track file added
    func trackFileAdded(fileType: String) async {
        await track(.fileAdded, metadata: ["type": fileType])
    }
    
    /// Track file opened
    func trackFileOpened(fileType: String) async {
        await track(.fileOpened, metadata: ["type": fileType])
    }
    
    /// Track note created
    func trackNoteCreated() async {
        await track(.noteCreated)
    }
    
    // MARK: - Statistics Retrieval
    
    /// Get total clips count
    func getTotalClips() async -> Int {
        do {
            try await database.open()
            let results = try await database.query(
                "SELECT COUNT(*) as count FROM analytics_events WHERE type = ?",
                parameters: [EventType.clipboardCopy.rawValue]
            )
            return results.first?["count"] as? Int ?? 0
        } catch {
            return 0
        }
    }
    
    /// Get clips count for time range
    func getClipsCount(from startDate: Date, to endDate: Date) async -> Int {
        do {
            try await database.open()
            let results = try await database.query(
                "SELECT COUNT(*) as count FROM analytics_events WHERE type = ? AND timestamp BETWEEN ? AND ?",
                parameters: [EventType.clipboardCopy.rawValue, startDate, endDate]
            )
            return results.first?["count"] as? Int ?? 0
        } catch {
            return 0
        }
    }
    
    /// Get daily stats for date range
    func getDailyStats(from startDate: Date, to endDate: Date) async -> [DailyStats] {
        do {
            try await database.open()
            let startStr = dateFormatter.string(from: startDate)
            let endStr = dateFormatter.string(from: endDate)
            
            let results = try await database.query(
                "SELECT * FROM analytics_daily WHERE date BETWEEN ? AND ? ORDER BY date",
                parameters: [startStr, endStr]
            )
            
            return results.compactMap { row -> DailyStats? in
                guard let date = row["date"] as? String else { return nil }
                return DailyStats(
                    date: date,
                    clipboardCopies: (row["clipboard_copies"] as? Int64).map { Int($0) } ?? 0,
                    clipboardPastes: (row["clipboard_pastes"] as? Int64).map { Int($0) } ?? 0,
                    snippetsUsed: (row["snippets_used"] as? Int64).map { Int($0) } ?? 0,
                    filesAdded: (row["files_added"] as? Int64).map { Int($0) } ?? 0,
                    filesOpened: (row["files_opened"] as? Int64).map { Int($0) } ?? 0,
                    notesCreated: (row["notes_created"] as? Int64).map { Int($0) } ?? 0,
                    searchCount: 0,
                    panelShows: 0
                )
            }
        } catch {
            return []
        }
    }
    
    /// Get category distribution
    func getCategoryDistribution() async -> [CategoryStat] {
        do {
            try await database.open()
            let results = try await database.query(
                "SELECT * FROM category_stats ORDER BY count DESC"
            )
            
            return results.compactMap { row -> CategoryStat? in
                guard let category = row["category"] as? String,
                      let count = row["count"] as? Int64 else { return nil }
                let lastUpdated = (row["last_updated"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()
                return CategoryStat(category: category, count: Int(count), lastUpdated: lastUpdated)
            }
        } catch {
            return []
        }
    }
    
    /// Get most used clips (top N)
    func getMostUsedCategories(limit: Int = 10) async -> [CategoryStat] {
        await getCategoryDistribution().prefix(limit).map { $0 }
    }
    
    /// Get usage for today
    func getTodayStats() async -> DailyStats {
        let today = dateFormatter.string(from: Date())
        
        // Check cache
        if let cached = dailyStatsCache[today] {
            return cached
        }
        
        do {
            try await database.open()
            let results = try await database.query(
                "SELECT * FROM analytics_daily WHERE date = ?",
                parameters: [today]
            )
            
            if let row = results.first {
                return DailyStats(
                    date: today,
                    clipboardCopies: (row["clipboard_copies"] as? Int64).map { Int($0) } ?? 0,
                    clipboardPastes: (row["clipboard_pastes"] as? Int64).map { Int($0) } ?? 0,
                    snippetsUsed: (row["snippets_used"] as? Int64).map { Int($0) } ?? 0,
                    filesAdded: (row["files_added"] as? Int64).map { Int($0) } ?? 0,
                    filesOpened: (row["files_opened"] as? Int64).map { Int($0) } ?? 0,
                    notesCreated: (row["notes_created"] as? Int64).map { Int($0) } ?? 0,
                    searchCount: 0,
                    panelShows: 0
                )
            }
        } catch {
            print("Failed to get today's stats: \(error)")
        }
        
        return DailyStats.empty(for: today)
    }
    
    /// Get this week's stats
    func getWeekStats() async -> [DailyStats] {
        let calendar = Calendar.current
        let today = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        
        return await getDailyStats(from: weekAgo, to: today)
    }
    
    /// Calculate productivity score (0-100)
    func getProductivityScore() async -> Int {
        let todayStats = await getTodayStats()
        
        // Simple scoring based on activity
        var score = 0
        score += min(todayStats.clipboardCopies * 2, 30)
        score += min(todayStats.snippetsUsed * 5, 30)
        score += min(todayStats.notesCreated * 10, 20)
        score += min(todayStats.filesAdded * 5, 20)
        
        return min(score, 100)
    }
    
    /// Estimate time saved (in seconds)
    func getTimeSaved() async -> Int {
        let todayStats = await getTodayStats()
        
        // Estimate time saved per action
        var seconds = 0
        seconds += todayStats.clipboardCopies * 2  // 2 sec per copy avoided
        seconds += todayStats.snippetsUsed * 10    // 10 sec per snippet
        seconds += todayStats.filesAdded * 5       // 5 sec per file access
        
        return seconds
    }
    
    // MARK: - Private Methods
    
    private func initializeDatabase() async {
        do {
            try await database.open()
            try await database.createAnalyticsTables()
        } catch {
            print("Failed to initialize analytics database: \(error)")
        }
    }
    
    private func updateDailyAggregate(for event: AnalyticsEvent) async {
        let today = dateFormatter.string(from: event.timestamp)
        
        do {
            // Get or create today's stats
            let results = try await database.query(
                "SELECT * FROM analytics_daily WHERE date = ?",
                parameters: [today]
            )
            
            if results.isEmpty {
                // Create new entry
                try await database.execute(
                    """
                    INSERT INTO analytics_daily (date, clipboard_copies, clipboard_pastes, snippets_used, files_added, files_opened, notes_created)
                    VALUES (?, 0, 0, 0, 0, 0, 0)
                    """,
                    parameters: [today]
                )
            }
            
            // Update appropriate counter
            let column: String
            switch event.type {
            case .clipboardCopy:
                column = "clipboard_copies"
            case .clipboardPaste:
                column = "clipboard_pastes"
            case .snippetUsed:
                column = "snippets_used"
            case .fileAdded:
                column = "files_added"
            case .fileOpened:
                column = "files_opened"
            case .noteCreated:
                column = "notes_created"
            default:
                return
            }
            
            try await database.execute(
                "UPDATE analytics_daily SET \(column) = \(column) + 1 WHERE date = ?",
                parameters: [today]
            )
            
            // Clear cache for today
            dailyStatsCache.removeValue(forKey: today)
            
        } catch {
            print("Failed to update daily aggregate: \(error)")
        }
    }
    
    private func updateCategoryStat(_ category: String) async {
        do {
            let results = try await database.query(
                "SELECT * FROM category_stats WHERE category = ?",
                parameters: [category]
            )
            
            if results.isEmpty {
                try await database.execute(
                    "INSERT INTO category_stats (category, count, last_updated) VALUES (?, 1, ?)",
                    parameters: [category, Date()]
                )
            } else {
                try await database.execute(
                    "UPDATE category_stats SET count = count + 1, last_updated = ? WHERE category = ?",
                    parameters: [Date(), category]
                )
            }
        } catch {
            print("Failed to update category stat: \(error)")
        }
    }
    
    /// Clean up old events (keep last 90 days)
    func cleanupOldData() async {
        do {
            try await database.open()
            let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
            
            try await database.execute(
                "DELETE FROM analytics_events WHERE timestamp < ?",
                parameters: [cutoff]
            )
        } catch {
            print("Failed to cleanup old analytics data: \(error)")
        }
    }
}

// MARK: - Analytics Extensions

extension AnalyticsManager {
    /// Get hourly activity heatmap for the past week
    func getHourlyHeatmap() async -> [Int: Int] {
        var heatmap: [Int: Int] = [:]
        
        do {
            try await database.open()
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            
            let results = try await database.query(
                "SELECT timestamp FROM analytics_events WHERE timestamp > ?",
                parameters: [weekAgo]
            )
            
            for row in results {
                if let timestampStr = row["timestamp"] as? String,
                   let timestamp = ISO8601DateFormatter().date(from: timestampStr) {
                    let hour = Calendar.current.component(.hour, from: timestamp)
                    heatmap[hour, default: 0] += 1
                }
            }
        } catch {
            print("Failed to get hourly heatmap: \(error)")
        }
        
        return heatmap
    }
    
    /// Get peak usage hours
    func getPeakHours() async -> [Int] {
        let heatmap = await getHourlyHeatmap()
        return heatmap.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
    }
}
