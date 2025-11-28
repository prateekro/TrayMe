//
//  AnalyticsDashboardView.swift
//  TrayMe
//
//  Analytics dashboard with charts and statistics

import SwiftUI
import Charts

struct AnalyticsDashboardView: View {
    @State private var todayStats: DailyStats = DailyStats.empty(for: "")
    @State private var weekStats: [DailyStats] = []
    @State private var categoryStats: [CategoryStat] = []
    @State private var productivityScore: Int = 0
    @State private var timeSaved: Int = 0
    @State private var totalClips: Int = 0
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("Analytics")
                        .font(.title2.bold())
                    
                    Spacer()
                    
                    Button(action: refreshData) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                }
                .padding(.horizontal)
                .padding(.top)
                
                if isLoading {
                    ProgressView()
                        .padding(50)
                } else {
                    // Stats cards row
                    HStack(spacing: 16) {
                        StatsCardView(
                            title: "Today's Clips",
                            value: "\(todayStats.clipboardCopies)",
                            icon: "doc.on.clipboard",
                            color: .blue
                        )
                        
                        StatsCardView(
                            title: "Snippets Used",
                            value: "\(todayStats.snippetsUsed)",
                            icon: "text.badge.plus",
                            color: .purple
                        )
                        
                        StatsCardView(
                            title: "Time Saved",
                            value: formatTimeSaved(timeSaved),
                            icon: "clock.badge.checkmark",
                            color: .green
                        )
                        
                        StatsCardView(
                            title: "Productivity",
                            value: "\(productivityScore)%",
                            icon: "chart.line.uptrend.xyaxis",
                            color: productivityColor
                        )
                    }
                    .padding(.horizontal)
                    
                    // Charts row
                    HStack(spacing: 16) {
                        // Weekly activity chart
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Weekly Activity")
                                .font(.headline)
                            
                            if !weekStats.isEmpty {
                                Chart(weekStats, id: \.date) { stat in
                                    BarMark(
                                        x: .value("Day", formatDayOfWeek(stat.date)),
                                        y: .value("Clips", stat.clipboardCopies)
                                    )
                                    .foregroundStyle(Color.blue.gradient)
                                }
                                .frame(height: 150)
                            } else {
                                Text("No data yet")
                                    .foregroundColor(.secondary)
                                    .frame(height: 150)
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)
                        
                        // Category breakdown
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Category Breakdown")
                                .font(.headline)
                            
                            if !categoryStats.isEmpty {
                                Chart(categoryStats) { stat in
                                    SectorMark(
                                        angle: .value("Count", stat.count),
                                        innerRadius: .ratio(0.5),
                                        angularInset: 1.5
                                    )
                                    .foregroundStyle(by: .value("Category", stat.category))
                                    .annotation(position: .overlay) {
                                        Text("\(stat.count)")
                                            .font(.caption2)
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(height: 150)
                            } else {
                                Text("No data yet")
                                    .foregroundColor(.secondary)
                                    .frame(height: 150)
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Additional stats
                    HStack(spacing: 16) {
                        // Quick stats
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Summary")
                                .font(.headline)
                            
                            SummaryRow(
                                icon: "doc.on.clipboard.fill",
                                label: "Total Clips",
                                value: "\(totalClips)",
                                color: .blue
                            )
                            
                            SummaryRow(
                                icon: "doc.badge.plus",
                                label: "Files Added Today",
                                value: "\(todayStats.filesAdded)",
                                color: .orange
                            )
                            
                            SummaryRow(
                                icon: "note.text",
                                label: "Notes Created Today",
                                value: "\(todayStats.notesCreated)",
                                color: .green
                            )
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)
                        
                        // Tips
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tips")
                                .font(.headline)
                            
                            TipRow(
                                icon: "lightbulb.fill",
                                text: "Use snippets for frequently typed text",
                                color: .yellow
                            )
                            
                            TipRow(
                                icon: "star.fill",
                                text: "Star important clips to find them faster",
                                color: .orange
                            )
                            
                            TipRow(
                                icon: "keyboard",
                                text: "Press ⌘⌃⇧U to toggle TrayMe",
                                color: .blue
                            )
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .frame(height: 180)
                }
                
                Spacer()
            }
        }
        .task {
            await loadData()
        }
    }
    
    // MARK: - Helpers
    
    private var productivityColor: Color {
        switch productivityScore {
        case 0..<30: return .red
        case 30..<60: return .orange
        case 60..<80: return .yellow
        default: return .green
        }
    }
    
    private func formatTimeSaved(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        } else if seconds < 3600 {
            return "\(seconds / 60)m"
        } else {
            return "\(seconds / 3600)h"
        }
    }
    
    private func formatDayOfWeek(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"
        return dayFormatter.string(from: date)
    }
    
    // MARK: - Data Loading
    
    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        let manager = AnalyticsManager.shared
        
        async let today = manager.getTodayStats()
        async let week = manager.getWeekStats()
        async let categories = manager.getCategoryDistribution()
        async let score = manager.getProductivityScore()
        async let saved = manager.getTimeSaved()
        async let total = manager.getTotalClips()
        
        (todayStats, weekStats, categoryStats, productivityScore, timeSaved, totalClips) =
            await (today, week, categories, score, saved, total)
    }
    
    private func refreshData() {
        Task {
            await loadData()
        }
    }
}

// MARK: - Summary Row

struct SummaryRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(.body, design: .rounded).bold())
        }
    }
}

// MARK: - Tip Row

struct TipRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}
