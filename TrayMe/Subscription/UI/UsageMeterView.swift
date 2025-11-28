//
//  UsageMeterView.swift
//  TrayMe
//
//  Compact usage meter for status bar and settings

import SwiftUI

/// Compact usage meter for status bar
struct CompactUsageMeterView: View {
    @ObservedObject var manager = SubscriptionManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Clips
            UsagePill(
                icon: "doc.on.clipboard",
                current: manager.currentUsage.clipsCount,
                max: manager.limits.maxClips,
                color: .blue
            )
            
            // Notes
            UsagePill(
                icon: "note.text",
                current: manager.currentUsage.notesCount,
                max: manager.limits.maxNotes,
                color: .green
            )
            
            // Files
            UsagePill(
                icon: "folder",
                current: manager.currentUsage.filesCount,
                max: manager.limits.maxFiles,
                color: .orange
            )
        }
    }
}

// MARK: - Usage Pill

struct UsagePill: View {
    let icon: String
    let current: Int
    let max: Int
    let color: Color
    
    private var percentage: Double {
        guard max != Int.max && max > 0 else { return 0 }
        return min(Double(current) / Double(max), 1.0)
    }
    
    private var isUnlimited: Bool {
        max == Int.max
    }
    
    private var isNearLimit: Bool {
        !isUnlimited && percentage >= 0.8
    }
    
    private var isAtLimit: Bool {
        !isUnlimited && current >= max
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            
            if isUnlimited {
                Image(systemName: "infinity")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            } else {
                Text("\(current)/\(max)")
                    .font(.system(size: 10))
                    .foregroundColor(isAtLimit ? .red : (isNearLimit ? .orange : .secondary))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isAtLimit ? Color.red.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        )
    }
}

// MARK: - Full Usage Overview

struct FullUsageOverviewView: View {
    @ObservedObject var manager = SubscriptionManager.shared
    @State private var showUpgrade = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Usage")
                        .font(.headline)
                    
                    Text("Current plan: \(manager.currentTier.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if manager.currentTier == .free {
                    Button("Upgrade") {
                        showUpgrade = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            
            // Usage bars
            VStack(spacing: 12) {
                DetailedUsageBar(
                    label: "Clipboard Items",
                    icon: "doc.on.clipboard",
                    current: manager.currentUsage.clipsCount,
                    max: manager.limits.maxClips,
                    color: .blue
                )
                
                DetailedUsageBar(
                    label: "Notes",
                    icon: "note.text",
                    current: manager.currentUsage.notesCount,
                    max: manager.limits.maxNotes,
                    color: .green
                )
                
                DetailedUsageBar(
                    label: "Files",
                    icon: "folder",
                    current: manager.currentUsage.filesCount,
                    max: manager.limits.maxFiles,
                    color: .orange
                )
            }
            
            // Feature access
            if manager.currentTier == .free {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Locked Features")
                        .font(.subheadline.bold())
                    
                    HStack(spacing: 8) {
                        LockedFeatureBadge(name: "AI", icon: "brain")
                        LockedFeatureBadge(name: "Snippets", icon: "text.badge.plus")
                        LockedFeatureBadge(name: "Analytics", icon: "chart.bar")
                        LockedFeatureBadge(name: "Security", icon: "lock")
                    }
                }
            }
            
            // Trial remaining
            if manager.isTrialing {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.orange)
                    
                    Text("\(manager.trialDaysRemaining) days left in trial")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .sheet(isPresented: $showUpgrade) {
            UpgradeView()
        }
    }
}

// MARK: - Detailed Usage Bar

struct DetailedUsageBar: View {
    let label: String
    let icon: String
    let current: Int
    let max: Int
    let color: Color
    
    private var percentage: Double {
        guard max != Int.max && max > 0 else { return 0 }
        return min(Double(current) / Double(max), 1.0)
    }
    
    private var isUnlimited: Bool {
        max == Int.max
    }
    
    private var statusColor: Color {
        if isUnlimited { return color }
        if percentage >= 1.0 { return .red }
        if percentage >= 0.8 { return .orange }
        return color
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(statusColor)
                    .frame(width: 16)
                
                Text(label)
                    .font(.system(size: 12))
                
                Spacer()
                
                if isUnlimited {
                    HStack(spacing: 2) {
                        Text("\(current)")
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "infinity")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("\(current) / \(max)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(statusColor)
                }
            }
            
            if !isUnlimited {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color.opacity(0.2))
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(statusColor)
                            .frame(width: geometry.size.width * percentage)
                    }
                }
                .frame(height: 8)
            }
        }
    }
}

// MARK: - Locked Feature Badge

struct LockedFeatureBadge: View {
    let name: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            
            Text(name)
                .font(.system(size: 10))
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.1))
        )
        .overlay(
            Image(systemName: "lock.fill")
                .font(.system(size: 6))
                .foregroundColor(.secondary)
                .offset(x: 20, y: -8)
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        CompactUsageMeterView()
        
        Divider()
        
        FullUsageOverviewView()
    }
    .padding()
}
