//
//  SubscriptionManager.swift
//  TrayMe
//
//  Freemium tier management with StoreKit 2 integration

import Foundation
import StoreKit
import Combine
import os.log

/// Private logger for SubscriptionManager
private let logger = Logger(subsystem: "com.trayme.TrayMe", category: "SubscriptionManager")

/// Subscription tiers
enum SubscriptionTier: String, Codable, CaseIterable {
    case free = "free"      // 50 clips, 10 notes, 5 files, no AI
    case pro = "pro"        // Unlimited + AI + Sync
    case team = "team"      // Collaboration features
    
    var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
        case .team: return "Team"
        }
    }
    
    var icon: String {
        switch self {
        case .free: return "person"
        case .pro: return "star.fill"
        case .team: return "person.3.fill"
        }
    }
    
    var color: String {
        switch self {
        case .free: return "gray"
        case .pro: return "blue"
        case .team: return "purple"
        }
    }
}

/// Usage limits for each tier
struct UsageLimits: Codable {
    let maxClips: Int
    let maxNotes: Int
    let maxFiles: Int
    let aiEnabled: Bool
    let snippetsEnabled: Bool
    let analyticsEnabled: Bool
    let syncEnabled: Bool
    let securityEnabled: Bool
    
    static let free = UsageLimits(
        maxClips: 50,
        maxNotes: 10,
        maxFiles: 5,
        aiEnabled: false,
        snippetsEnabled: false,
        analyticsEnabled: false,
        syncEnabled: false,
        securityEnabled: false
    )
    
    static let pro = UsageLimits(
        maxClips: Int.max,
        maxNotes: Int.max,
        maxFiles: Int.max,
        aiEnabled: true,
        snippetsEnabled: true,
        analyticsEnabled: true,
        syncEnabled: true,
        securityEnabled: true
    )
    
    static let team = UsageLimits(
        maxClips: Int.max,
        maxNotes: Int.max,
        maxFiles: Int.max,
        aiEnabled: true,
        snippetsEnabled: true,
        analyticsEnabled: true,
        syncEnabled: true,
        securityEnabled: true
    )
    
    static func limits(for tier: SubscriptionTier) -> UsageLimits {
        switch tier {
        case .free: return .free
        case .pro: return .pro
        case .team: return .team
        }
    }
}

/// Current usage tracking
struct CurrentUsage: Codable {
    var clipsCount: Int
    var notesCount: Int
    var filesCount: Int
    var lastUpdated: Date
    
    static var empty: CurrentUsage {
        CurrentUsage(clipsCount: 0, notesCount: 0, filesCount: 0, lastUpdated: Date())
    }
}

/// Subscription manager with StoreKit 2 integration
@MainActor
class SubscriptionManager: ObservableObject {
    /// Shared instance
    static let shared = SubscriptionManager()
    
    /// Current subscription tier
    @Published var currentTier: SubscriptionTier = .free
    
    /// Current usage
    @Published var currentUsage: CurrentUsage = .empty
    
    /// Trial status
    @Published var isTrialing: Bool = false
    @Published var trialEndDate: Date?
    
    /// Available products
    @Published var products: [Product] = []
    
    /// Loading state
    @Published var isLoading: Bool = false
    
    /// Purchase in progress
    @Published var isPurchasing: Bool = false
    
    /// StoreKit product IDs
    private let productIds = [
        "com.trayme.pro.monthly",
        "com.trayme.pro.yearly",
        "com.trayme.team.monthly",
        "com.trayme.team.yearly"
    ]
    
    /// Transaction updates
    private var updateListenerTask: Task<Void, Error>?
    
    /// Persistence
    private let userDefaults = UserDefaults.standard
    private let tierKey = "SubscriptionManager.currentTier"
    private let usageKey = "SubscriptionManager.currentUsage"
    private let trialStartKey = "SubscriptionManager.trialStart"
    
    private init() {
        loadSavedState()
        startTransactionListener()
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
        }
    }
    
    // MARK: - Usage Limits
    
    /// Get current usage limits
    var limits: UsageLimits {
        UsageLimits.limits(for: currentTier)
    }
    
    /// Check if clips limit is reached
    var clipsLimitReached: Bool {
        currentUsage.clipsCount >= limits.maxClips
    }
    
    /// Check if notes limit is reached
    var notesLimitReached: Bool {
        currentUsage.notesCount >= limits.maxNotes
    }
    
    /// Check if files limit is reached
    var filesLimitReached: Bool {
        currentUsage.filesCount >= limits.maxFiles
    }
    
    /// Get clips usage percentage
    var clipsUsagePercentage: Double {
        guard limits.maxClips != Int.max else { return 0 }
        return Double(currentUsage.clipsCount) / Double(limits.maxClips)
    }
    
    /// Get notes usage percentage
    var notesUsagePercentage: Double {
        guard limits.maxNotes != Int.max else { return 0 }
        return Double(currentUsage.notesCount) / Double(limits.maxNotes)
    }
    
    /// Get files usage percentage
    var filesUsagePercentage: Double {
        guard limits.maxFiles != Int.max else { return 0 }
        return Double(currentUsage.filesCount) / Double(limits.maxFiles)
    }
    
    // MARK: - Feature Access
    
    /// Check if a feature is available
    func isFeatureAvailable(_ feature: Feature) -> Bool {
        switch feature {
        case .ai:
            return limits.aiEnabled
        case .snippets:
            return limits.snippetsEnabled
        case .analytics:
            return limits.analyticsEnabled
        case .sync:
            return limits.syncEnabled
        case .security:
            return limits.securityEnabled
        case .unlimitedClips:
            return limits.maxClips == Int.max
        case .unlimitedNotes:
            return limits.maxNotes == Int.max
        case .unlimitedFiles:
            return limits.maxFiles == Int.max
        }
    }
    
    enum Feature {
        case ai
        case snippets
        case analytics
        case sync
        case security
        case unlimitedClips
        case unlimitedNotes
        case unlimitedFiles
    }
    
    // MARK: - Usage Tracking
    
    /// Update clips count
    func updateClipsCount(_ count: Int) {
        currentUsage.clipsCount = count
        currentUsage.lastUpdated = Date()
        saveState()
    }
    
    /// Update notes count
    func updateNotesCount(_ count: Int) {
        currentUsage.notesCount = count
        currentUsage.lastUpdated = Date()
        saveState()
    }
    
    /// Update files count
    func updateFilesCount(_ count: Int) {
        currentUsage.filesCount = count
        currentUsage.lastUpdated = Date()
        saveState()
    }
    
    /// Check if can add clip
    func canAddClip() -> Bool {
        !clipsLimitReached
    }
    
    /// Check if can add note
    func canAddNote() -> Bool {
        !notesLimitReached
    }
    
    /// Check if can add file
    func canAddFile() -> Bool {
        !filesLimitReached
    }
    
    // MARK: - Trial Management
    
    /// Start free trial
    func startTrial() {
        guard !isTrialing && currentTier == .free else { return }
        
        let trialDays = 14
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: trialDays, to: startDate)!
        
        userDefaults.set(startDate, forKey: trialStartKey)
        
        isTrialing = true
        trialEndDate = endDate
        currentTier = .pro // Trial gives Pro access
        
        saveState()
    }
    
    /// Check trial status
    func checkTrialStatus() {
        guard let trialStart = userDefaults.object(forKey: trialStartKey) as? Date else {
            return
        }
        
        let trialDays = 14
        let trialEnd = Calendar.current.date(byAdding: .day, value: trialDays, to: trialStart)!
        
        if Date() < trialEnd {
            isTrialing = true
            trialEndDate = trialEnd
            currentTier = .pro
        } else {
            isTrialing = false
            trialEndDate = nil
            // Revert to free if no active subscription
            Task {
                await updateSubscriptionStatus()
            }
        }
    }
    
    /// Days remaining in trial
    var trialDaysRemaining: Int {
        guard let endDate = trialEndDate, isTrialing else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0
        return max(0, days)
    }
    
    // MARK: - StoreKit Integration
    
    /// Load available products
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            products = try await Product.products(for: productIds)
        } catch {
            logger.error("Failed to load products: \(error.localizedDescription)")
        }
    }
    
    /// Purchase a product
    func purchase(_ product: Product) async throws -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateSubscriptionStatus()
            await transaction.finish()
            return true
            
        case .userCancelled:
            return false
            
        case .pending:
            return false
            
        @unknown default:
            return false
        }
    }
    
    /// Restore purchases
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
        } catch {
            logger.error("Failed to restore purchases: \(error.localizedDescription)")
        }
    }
    
    /// Update subscription status from App Store
    func updateSubscriptionStatus() async {
        var hasActiveSubscription = false
        var activeTier: SubscriptionTier = .free
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // Check if this transaction gives us a subscription
                if transaction.productID.contains("pro") {
                    hasActiveSubscription = true
                    activeTier = .pro
                } else if transaction.productID.contains("team") {
                    hasActiveSubscription = true
                    activeTier = .team
                }
            } catch {
                logger.warning("Transaction verification failed: \(error.localizedDescription)")
            }
        }
        
        if hasActiveSubscription {
            currentTier = activeTier
            isTrialing = false
        } else if !isTrialing {
            currentTier = .free
        }
        
        saveState()
    }
    
    // MARK: - Private Methods
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    private func startTransactionListener() {
        updateListenerTask = Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updateSubscriptionStatus()
                    await transaction.finish()
                } catch {
                    logger.warning("Transaction update failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func loadSavedState() {
        if let tierString = userDefaults.string(forKey: tierKey),
           let tier = SubscriptionTier(rawValue: tierString) {
            currentTier = tier
        }
        
        if let usageData = userDefaults.data(forKey: usageKey),
           let usage = try? JSONDecoder().decode(CurrentUsage.self, from: usageData) {
            currentUsage = usage
        }
        
        checkTrialStatus()
    }
    
    private func saveState() {
        userDefaults.set(currentTier.rawValue, forKey: tierKey)
        
        if let usageData = try? JSONEncoder().encode(currentUsage) {
            userDefaults.set(usageData, forKey: usageKey)
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
}

// MARK: - Errors

enum StoreError: Error {
    case verificationFailed
    case purchaseFailed
    case productNotFound
}
