//
//  StatsCardView.swift
//  TrayMe
//
//  Reusable statistics card component

import SwiftUI

struct StatsCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var trend: Double? = nil
    var subtitle: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Icon and title
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 14))
                
                Spacer()
                
                if let trend = trend {
                    TrendIndicator(value: trend)
                }
            }
            
            // Value
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            // Title
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            // Optional subtitle
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.8))
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Trend Indicator

struct TrendIndicator: View {
    let value: Double
    
    private var isPositive: Bool { value >= 0 }
    private var color: Color { isPositive ? .green : .red }
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 10, weight: .semibold))
            
            Text(String(format: "%.0f%%", abs(value)))
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.15))
        .cornerRadius(4)
    }
}

// MARK: - Large Stats Card

struct LargeStatsCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: icon)
                            .foregroundColor(color)
                    )
                
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(16)
    }
}

// MARK: - Mini Stats Badge

struct MiniStatsBadge: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Progress Ring

struct ProgressRing: View {
    let progress: Double
    let color: Color
    let label: String
    var lineWidth: CGFloat = 8
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
            
            // Label
            VStack(spacing: 2) {
                Text(String(format: "%.0f%%", progress * 100))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Stats Row

struct StatsRow: View {
    let items: [(label: String, value: String, color: Color)]
    
    var body: some View {
        HStack(spacing: 16) {
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.value)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(item.color)
                    
                    Text(item.label)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                if index < items.count - 1 {
                    Divider()
                        .frame(height: 30)
                }
            }
        }
    }
}

// MARK: - Heatmap Cell

struct HeatmapCell: View {
    let value: Int
    let maxValue: Int
    let color: Color
    
    private var intensity: Double {
        guard maxValue > 0 else { return 0 }
        return Double(value) / Double(maxValue)
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(color.opacity(0.1 + intensity * 0.9))
            .frame(width: 16, height: 16)
    }
}

// MARK: - Weekly Heatmap

struct WeeklyHeatmap: View {
    let data: [Int: Int] // Hour -> count
    let color: Color
    
    private var maxValue: Int {
        data.values.max() ?? 1
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Hour labels at top
            HStack(spacing: 0) {
                Text("") // Spacer for row labels
                    .frame(width: 30)
                
                ForEach([0, 6, 12, 18], id: \.self) { hour in
                    Text("\(hour):00")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)
                }
            }
            
            // Grid
            HStack(spacing: 2) {
                ForEach(0..<24, id: \.self) { hour in
                    HeatmapCell(
                        value: data[hour] ?? 0,
                        maxValue: maxValue,
                        color: color
                    )
                    .help("\(data[hour] ?? 0) activities at \(hour):00")
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 16) {
            StatsCardView(
                title: "Today's Clips",
                value: "42",
                icon: "doc.on.clipboard",
                color: .blue,
                trend: 12.5
            )
            
            StatsCardView(
                title: "Snippets Used",
                value: "15",
                icon: "text.badge.plus",
                color: .purple,
                trend: -5.2
            )
        }
        
        HStack(spacing: 16) {
            MiniStatsBadge(value: "127", label: "This Week", color: .blue)
            MiniStatsBadge(value: "89%", label: "Productivity", color: .green)
            MiniStatsBadge(value: "23m", label: "Time Saved", color: .orange)
        }
        
        ProgressRing(progress: 0.73, color: .green, label: "Score")
            .frame(width: 80, height: 80)
    }
    .padding()
}
