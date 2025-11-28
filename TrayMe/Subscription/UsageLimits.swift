//
//  UsageLimits.swift
//  TrayMe
//
//  Usage limits and feature gating utilities

import Foundation
import SwiftUI

/// Feature gating result
enum FeatureGateResult {
    case allowed
    case limitReached(current: Int, max: Int)
    case requiresUpgrade(feature: String)
    
    var isAllowed: Bool {
        if case .allowed = self {
            return true
        }
        return false
    }
    
    var message: String {
        switch self {
        case .allowed:
            return ""
        case .limitReached(let current, let max):
            return "You've reached your limit (\(current)/\(max)). Upgrade to Pro for unlimited access."
        case .requiresUpgrade(let feature):
            return "\(feature) is a Pro feature. Upgrade to unlock it."
        }
    }
}

/// Usage limit checker
struct UsageLimitChecker {
    let manager: SubscriptionManager
    
    init(manager: SubscriptionManager = .shared) {
        self.manager = manager
    }
    
    /// Check if can add a clip
    func checkAddClip() -> FeatureGateResult {
        let limits = manager.limits
        let current = manager.currentUsage.clipsCount
        
        if limits.maxClips == Int.max || current < limits.maxClips {
            return .allowed
        }
        return .limitReached(current: current, max: limits.maxClips)
    }
    
    /// Check if can add a note
    func checkAddNote() -> FeatureGateResult {
        let limits = manager.limits
        let current = manager.currentUsage.notesCount
        
        if limits.maxNotes == Int.max || current < limits.maxNotes {
            return .allowed
        }
        return .limitReached(current: current, max: limits.maxNotes)
    }
    
    /// Check if can add a file
    func checkAddFile() -> FeatureGateResult {
        let limits = manager.limits
        let current = manager.currentUsage.filesCount
        
        if limits.maxFiles == Int.max || current < limits.maxFiles {
            return .allowed
        }
        return .limitReached(current: current, max: limits.maxFiles)
    }
    
    /// Check if AI features are available
    func checkAIAccess() -> FeatureGateResult {
        if manager.limits.aiEnabled {
            return .allowed
        }
        return .requiresUpgrade(feature: "AI-powered features")
    }
    
    /// Check if snippets are available
    func checkSnippetsAccess() -> FeatureGateResult {
        if manager.limits.snippetsEnabled {
            return .allowed
        }
        return .requiresUpgrade(feature: "Text snippets")
    }
    
    /// Check if analytics are available
    func checkAnalyticsAccess() -> FeatureGateResult {
        if manager.limits.analyticsEnabled {
            return .allowed
        }
        return .requiresUpgrade(feature: "Analytics dashboard")
    }
    
    /// Check if security features are available
    func checkSecurityAccess() -> FeatureGateResult {
        if manager.limits.securityEnabled {
            return .allowed
        }
        return .requiresUpgrade(feature: "Security features")
    }
}

// MARK: - Usage Meter View

struct UsageMeterView: View {
    @ObservedObject var manager = SubscriptionManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Clips usage
            UsageBar(
                label: "Clips",
                current: manager.currentUsage.clipsCount,
                max: manager.limits.maxClips,
                color: .blue
            )
            
            // Notes usage
            UsageBar(
                label: "Notes",
                current: manager.currentUsage.notesCount,
                max: manager.limits.maxNotes,
                color: .green
            )
            
            // Files usage
            UsageBar(
                label: "Files",
                current: manager.currentUsage.filesCount,
                max: manager.limits.maxFiles,
                color: .orange
            )
        }
    }
}

// MARK: - Usage Bar

struct UsageBar: View {
    let label: String
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
    
    private var isAtLimit: Bool {
        !isUnlimited && current >= max
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 12))
                
                Spacer()
                
                if isUnlimited {
                    Text("Unlimited")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else {
                    Text("\(current) / \(max)")
                        .font(.system(size: 11))
                        .foregroundColor(isAtLimit ? .red : .secondary)
                }
            }
            
            if !isUnlimited {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color.opacity(0.2))
                        
                        // Progress
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isAtLimit ? Color.red : color)
                            .frame(width: geometry.size.width * percentage)
                    }
                }
                .frame(height: 6)
            }
        }
    }
}

// MARK: - Feature Badge

struct FeatureBadge: View {
    let feature: String
    let isAvailable: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isAvailable ? "checkmark.circle.fill" : "lock.fill")
                .font(.system(size: 10))
            
            Text(feature)
                .font(.system(size: 11))
        }
        .foregroundColor(isAvailable ? .green : .secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill((isAvailable ? Color.green : Color.secondary).opacity(0.1))
        )
    }
}

// MARK: - Upgrade Prompt

struct UpgradePromptView: View {
    let message: String
    let onUpgrade: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "star.fill")
                .foregroundColor(.yellow)
            
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("Upgrade") {
                onUpgrade()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.yellow.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Tier Comparison

struct TierFeature: Identifiable {
    let id = UUID()
    let name: String
    let freeValue: String
    let proValue: String
    let teamValue: String
}

let tierFeatures: [TierFeature] = [
    TierFeature(name: "Clipboard Items", freeValue: "50", proValue: "Unlimited", teamValue: "Unlimited"),
    TierFeature(name: "Notes", freeValue: "10", proValue: "Unlimited", teamValue: "Unlimited"),
    TierFeature(name: "Files", freeValue: "5", proValue: "Unlimited", teamValue: "Unlimited"),
    TierFeature(name: "AI Features", freeValue: "❌", proValue: "✓", teamValue: "✓"),
    TierFeature(name: "Text Snippets", freeValue: "❌", proValue: "✓", teamValue: "✓"),
    TierFeature(name: "Analytics", freeValue: "❌", proValue: "✓", teamValue: "✓"),
    TierFeature(name: "Security", freeValue: "❌", proValue: "✓", teamValue: "✓"),
    TierFeature(name: "iCloud Sync", freeValue: "❌", proValue: "✓", teamValue: "✓"),
    TierFeature(name: "Team Sharing", freeValue: "❌", proValue: "❌", teamValue: "✓"),
]
