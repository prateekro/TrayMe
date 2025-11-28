//
//  AnalyticsDatabase.swift
//  TrayMe
//
//  Analytics database queries and helpers

import Foundation

/// Analytics database helper for complex queries
actor AnalyticsDatabase {
    /// Shared instance
    static let shared = AnalyticsDatabase()
    
    private var database: DatabaseManager { DatabaseManager.shared }
    
    private init() {}
    
    // MARK: - Clipboard Statistics
    
    /// Get clipboard category breakdown
    func getCategoryBreakdown() async -> [String: Int] {
        do {
            try await database.open()
            
            let results = try await database.query("""
                SELECT metadata FROM analytics_events 
                WHERE type = 'clipboard_copy' 
                AND metadata IS NOT NULL
            """)
            
            var breakdown: [String: Int] = [:]
            let decoder = JSONDecoder()
            
            for row in results {
                if let metadataStr = row["metadata"] as? String,
                   let data = metadataStr.data(using: .utf8),
                   let metadata = try? decoder.decode([String: String].self, from: data),
                   let category = metadata["category"] {
                    breakdown[category, default: 0] += 1
                }
            }
            
            return breakdown
        } catch {
            return [:]
        }
    }
    
    /// Get most copied content types
    func getMostCopiedTypes(limit: Int = 5) async -> [(type: String, count: Int)] {
        let breakdown = await getCategoryBreakdown()
        return breakdown
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { ($0.key, $0.value) }
    }
    
    // MARK: - Snippet Statistics
    
    /// Get most used snippets
    func getMostUsedSnippets(limit: Int = 10) async -> [(trigger: String, count: Int)] {
        do {
            try await database.open()
            
            let results = try await database.query("""
                SELECT metadata FROM analytics_events 
                WHERE type = 'snippet_used'
            """)
            
            var usage: [String: Int] = [:]
            let decoder = JSONDecoder()
            
            for row in results {
                if let metadataStr = row["metadata"] as? String,
                   let data = metadataStr.data(using: .utf8),
                   let metadata = try? decoder.decode([String: String].self, from: data),
                   let trigger = metadata["trigger"] {
                    usage[trigger, default: 0] += 1
                }
            }
            
            return usage
                .sorted { $0.value > $1.value }
                .prefix(limit)
                .map { ($0.key, $0.value) }
        } catch {
            return []
        }
    }
    
    /// Get snippet usage over time
    func getSnippetUsageByDay(days: Int = 7) async -> [String: Int] {
        do {
            try await database.open()
            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            let results = try await database.query("""
                SELECT date FROM analytics_daily 
                WHERE date >= ? 
                ORDER BY date
            """, parameters: [dateFormatter.string(from: cutoff)])
            
            var usage: [String: Int] = [:]
            for row in results {
                if let date = row["date"] as? String,
                   let count = row["snippets_used"] as? Int64 {
                    usage[date] = Int(count)
                }
            }
            
            return usage
        } catch {
            return [:]
        }
    }
    
    // MARK: - File Statistics
    
    /// Get most common file types added
    func getMostCommonFileTypes(limit: Int = 5) async -> [(type: String, count: Int)] {
        do {
            try await database.open()
            
            let results = try await database.query("""
                SELECT metadata FROM analytics_events 
                WHERE type = 'file_added'
            """)
            
            var types: [String: Int] = [:]
            let decoder = JSONDecoder()
            
            for row in results {
                if let metadataStr = row["metadata"] as? String,
                   let data = metadataStr.data(using: .utf8),
                   let metadata = try? decoder.decode([String: String].self, from: data),
                   let fileType = metadata["type"] {
                    types[fileType, default: 0] += 1
                }
            }
            
            return types
                .sorted { $0.value > $1.value }
                .prefix(limit)
                .map { ($0.key, $0.value) }
        } catch {
            return []
        }
    }
    
    // MARK: - Activity Patterns
    
    /// Get activity by day of week
    func getActivityByDayOfWeek() async -> [Int: Int] {
        do {
            try await database.open()
            
            let results = try await database.query("""
                SELECT timestamp FROM analytics_events
            """)
            
            var activity: [Int: Int] = [:]
            
            for row in results {
                if let timestampStr = row["timestamp"] as? String,
                   let timestamp = ISO8601DateFormatter().date(from: timestampStr) {
                    let weekday = Calendar.current.component(.weekday, from: timestamp)
                    activity[weekday, default: 0] += 1
                }
            }
            
            return activity
        } catch {
            return [:]
        }
    }
    
    /// Get busiest day of week (1 = Sunday, 7 = Saturday)
    func getBusiestDayOfWeek() async -> Int? {
        let activity = await getActivityByDayOfWeek()
        return activity.max { $0.value < $1.value }?.key
    }
    
    // MARK: - Trends
    
    /// Get activity trend (compared to previous period)
    func getActivityTrend(days: Int = 7) async -> Double {
        do {
            try await database.open()
            
            let now = Date()
            let periodStart = Calendar.current.date(byAdding: .day, value: -days, to: now)!
            let previousStart = Calendar.current.date(byAdding: .day, value: -days * 2, to: now)!
            
            // Current period count
            let currentResults = try await database.query("""
                SELECT COUNT(*) as count FROM analytics_events 
                WHERE timestamp >= ?
            """, parameters: [periodStart])
            let currentCount = (currentResults.first?["count"] as? Int64) ?? 0
            
            // Previous period count
            let previousResults = try await database.query("""
                SELECT COUNT(*) as count FROM analytics_events 
                WHERE timestamp >= ? AND timestamp < ?
            """, parameters: [previousStart, periodStart])
            let previousCount = (previousResults.first?["count"] as? Int64) ?? 0
            
            guard previousCount > 0 else { return 0 }
            
            return Double(currentCount - previousCount) / Double(previousCount) * 100
        } catch {
            return 0
        }
    }
    
    // MARK: - Aggregation
    
    /// Aggregate old events into daily stats
    func aggregateOldEvents(olderThan days: Int = 30) async {
        do {
            try await database.open()
            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
            
            // This would be run periodically to roll up old detailed events into daily aggregates
            // For now, daily aggregation happens in real-time in AnalyticsManager
            
            // Delete old raw events after they're aggregated
            try await database.execute("""
                DELETE FROM analytics_events 
                WHERE timestamp < ?
            """, parameters: [cutoff])
            
        } catch {
            print("Failed to aggregate old events: \(error)")
        }
    }
}
