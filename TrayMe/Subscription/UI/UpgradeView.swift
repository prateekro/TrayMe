//
//  UpgradeView.swift
//  TrayMe
//
//  Upgrade and subscription management view

import SwiftUI
import StoreKit

struct UpgradeView: View {
    @ObservedObject var manager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlan: String?
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Upgrade to Pro")
                        .font(.title.bold())
                    
                    Text("Unlock all features and remove limits")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Current plan badge
                    CurrentPlanBadge(tier: manager.currentTier, isTrialing: manager.isTrialing)
                    
                    // Trial banner
                    if manager.currentTier == .free && !manager.isTrialing {
                        TrialBanner(onStartTrial: { manager.startTrial() })
                    }
                    
                    // Feature comparison
                    FeatureComparisonTable()
                    
                    // Pricing plans
                    PricingPlansView(
                        products: manager.products,
                        selectedPlan: $selectedPlan,
                        isLoading: manager.isLoading,
                        onPurchase: purchase
                    )
                    
                    // Restore purchases
                    Button("Restore Purchases") {
                        Task {
                            await manager.restorePurchases()
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    .font(.system(size: 12))
                    
                    // Legal links
                    HStack {
                        Link("Terms of Service", destination: URL(string: "https://trayme.app/terms")!)
                        Text("•")
                        Link("Privacy Policy", destination: URL(string: "https://trayme.app/privacy")!)
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                }
                .padding()
            }
        }
        .frame(width: 600, height: 700)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func purchase(_ product: Product) {
        Task {
            do {
                let success = try await manager.purchase(product)
                if success {
                    dismiss()
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Current Plan Badge

struct CurrentPlanBadge: View {
    let tier: SubscriptionTier
    let isTrialing: Bool
    
    var body: some View {
        HStack {
            Image(systemName: tier.icon)
                .font(.title2)
            
            VStack(alignment: .leading) {
                HStack {
                    Text("Current Plan: \(tier.displayName)")
                        .font(.headline)
                    
                    if isTrialing {
                        Text("TRIAL")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .cornerRadius(4)
                    }
                }
                
                if tier == .free {
                    Text("Limited features available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - Trial Banner

struct TrialBanner: View {
    let onStartTrial: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "gift.fill")
                    .font(.title)
                    .foregroundColor(.purple)
                
                VStack(alignment: .leading) {
                    Text("Try Pro Free for 14 Days")
                        .font(.headline)
                    
                    Text("No credit card required")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Start Trial") {
                    onStartTrial()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Feature Comparison Table

struct FeatureComparisonTable: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Compare Plans")
                .font(.headline)
                .padding(.bottom, 12)
            
            // Header row
            HStack {
                Text("Feature")
                    .frame(width: 150, alignment: .leading)
                
                Text("Free")
                    .frame(maxWidth: .infinity)
                
                Text("Pro")
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.blue)
                    .fontWeight(.semibold)
                
                Text("Team")
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.purple)
            }
            .font(.system(size: 12, weight: .semibold))
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            // Feature rows
            ForEach(tierFeatures) { feature in
                HStack {
                    Text(feature.name)
                        .frame(width: 150, alignment: .leading)
                    
                    FeatureValue(value: feature.freeValue)
                        .frame(maxWidth: .infinity)
                    
                    FeatureValue(value: feature.proValue)
                        .frame(maxWidth: .infinity)
                    
                    FeatureValue(value: feature.teamValue)
                        .frame(maxWidth: .infinity)
                }
                .font(.system(size: 12))
                .padding(.vertical, 8)
                
                Divider()
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct FeatureValue: View {
    let value: String
    
    var body: some View {
        if value == "✓" {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        } else if value == "❌" {
            Image(systemName: "xmark.circle")
                .foregroundColor(.secondary)
        } else {
            Text(value)
                .foregroundColor(value == "Unlimited" ? .green : .primary)
        }
    }
}

// MARK: - Pricing Plans View

struct PricingPlansView: View {
    let products: [Product]
    @Binding var selectedPlan: String?
    let isLoading: Bool
    let onPurchase: (Product) -> Void
    
    private var monthlyProducts: [Product] {
        products.filter { $0.id.contains("monthly") }
    }
    
    private var yearlyProducts: [Product] {
        products.filter { $0.id.contains("yearly") }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pricing")
                .font(.headline)
            
            if isLoading {
                ProgressView()
                    .padding()
            } else if products.isEmpty {
                Text("Unable to load pricing. Please try again later.")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                // Monthly plans
                HStack(spacing: 16) {
                    ForEach(monthlyProducts, id: \.id) { product in
                        PricingCard(
                            product: product,
                            isSelected: selectedPlan == product.id,
                            onSelect: { selectedPlan = product.id },
                            onPurchase: { onPurchase(product) }
                        )
                    }
                }
                
                // Yearly plans (with savings badge)
                HStack(spacing: 16) {
                    ForEach(yearlyProducts, id: \.id) { product in
                        PricingCard(
                            product: product,
                            isSelected: selectedPlan == product.id,
                            showSavings: true,
                            onSelect: { selectedPlan = product.id },
                            onPurchase: { onPurchase(product) }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Pricing Card

struct PricingCard: View {
    let product: Product
    let isSelected: Bool
    var showSavings: Bool = false
    let onSelect: () -> Void
    let onPurchase: () -> Void
    
    private var isPro: Bool {
        product.id.contains("pro")
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text(isPro ? "Pro" : "Team")
                    .font(.headline)
                
                Spacer()
                
                if showSavings {
                    Text("Save 20%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green)
                        .cornerRadius(4)
                }
            }
            
            // Price
            Text(product.displayPrice)
                .font(.system(size: 28, weight: .bold))
            
            Text(product.id.contains("yearly") ? "/year" : "/month")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
            
            // Subscribe button
            Button(action: onPurchase) {
                Text("Subscribe")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(isPro ? .blue : .purple)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? (isPro ? Color.blue : Color.purple) : Color.clear, lineWidth: 2)
                )
        )
        .onTapGesture(perform: onSelect)
    }
}
