//
//  MainPanelView.swift
//  TrayMe
//

import SwiftUI
import Combine

class PanelState: ObservableObject {
    @Published var selectedTab: PanelTab = .clipboard
    
    enum PanelTab: CaseIterable {
        case clipboard, files, notes, snippets, analytics
        
        var title: String {
            switch self {
            case .clipboard: return "Clipboard"
            case .files: return "Files"
            case .notes: return "Notes"
            case .snippets: return "Snippets"
            case .analytics: return "Analytics"
            }
        }
        
        var icon: String {
            switch self {
            case .clipboard: return "doc.on.clipboard"
            case .files: return "folder"
            case .notes: return "note.text"
            case .snippets: return "text.badge.plus"
            case .analytics: return "chart.bar"
            }
        }
    }
}

struct MainPanelView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @EnvironmentObject var filesManager: FilesManager
    @EnvironmentObject var notesManager: NotesManager
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var panelState: PanelState
    @StateObject private var snippetManager = SnippetManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var securityManager = SecurityManager.shared
    
    @Environment(\.openSettings) private var openSettings
    @State private var showUpgradeSheet = false
    @State private var showLockScreen = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Top bar with section titles and settings
            HStack(spacing: 0) {
                // Clipboard header
                TabHeaderButton(tab: .clipboard, currentTab: $panelState.selectedTab)
                
                Divider()
                    .frame(height: 20)
                
                // Files header
                TabHeaderButton(tab: .files, currentTab: $panelState.selectedTab)
                
                Divider()
                    .frame(height: 20)
                
                // Notes header
                TabHeaderButton(tab: .notes, currentTab: $panelState.selectedTab)
                
                Divider()
                    .frame(height: 20)
                
                // Snippets header (Pro feature)
                TabHeaderButton(tab: .snippets, currentTab: $panelState.selectedTab, requiresPro: !subscriptionManager.isFeatureAvailable(.snippets))
                
                Divider()
                    .frame(height: 20)
                
                // Analytics header (Pro feature)
                TabHeaderButton(tab: .analytics, currentTab: $panelState.selectedTab, requiresPro: !subscriptionManager.isFeatureAvailable(.analytics))
                
                Divider()
                    .frame(height: 20)
                
                // Lock/Unlock button
                Button(action: {
                    if securityManager.isUnlocked {
                        securityManager.lock()
                    } else {
                        Task {
                            await securityManager.authenticate()
                        }
                    }
                }) {
                    Image(systemName: securityManager.isUnlocked ? "lock.open.fill" : "lock.fill")
                        .foregroundColor(securityManager.isUnlocked ? .green : .orange)
                }
                .buttonStyle(.plain)
                .help(securityManager.isUnlocked ? "Lock" : "Unlock")
                
                // Settings button
                Button(action: {
                    // Close the panel first (if we can get the reference)
                    if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                        appDelegate.mainPanel?.hide()
                    }
                    // Always open settings regardless
                    openSettings()
                }) {
                    Image(systemName: "gearshape")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 12)
                
                // Subscription badge
                if subscriptionManager.currentTier != .free {
                    Text(subscriptionManager.currentTier.displayName.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(subscriptionManager.currentTier == .pro ? Color.blue : Color.purple)
                        .cornerRadius(4)
                        .padding(.leading, 4)
                } else if subscriptionManager.isTrialing {
                    Text("TRIAL")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .cornerRadius(4)
                        .padding(.leading, 4)
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Content based on selected tab
            Group {
                switch panelState.selectedTab {
                case .clipboard, .files, .notes:
                    // Original three-panel layout for core features
                    ThreePanelSplitView(
                        clipboardView: AnyView(ClipboardView().environmentObject(clipboardManager)),
                        filesView: AnyView(FilesView().environmentObject(filesManager)),
                        notesView: AnyView(NotesView().environmentObject(notesManager)),
                        selectedTab: panelState.selectedTab
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                case .snippets:
                    if subscriptionManager.isFeatureAvailable(.snippets) {
                        SnippetView()
                            .environmentObject(snippetManager)
                    } else {
                        FeatureLockedView(feature: "Snippets", onUpgrade: { showUpgradeSheet = true })
                    }
                    
                case .analytics:
                    if subscriptionManager.isFeatureAvailable(.analytics) {
                        AnalyticsDashboardView()
                    } else {
                        FeatureLockedView(feature: "Analytics", onUpgrade: { showUpgradeSheet = true })
                    }
                }
            }
        }
        .background(VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow))
        .cornerRadius(12)
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradeView()
        }
    }
}

// MARK: - Tab Header Button

struct TabHeaderButton: View {
    let tab: PanelState.PanelTab
    @Binding var currentTab: PanelState.PanelTab
    var requiresPro: Bool = false
    
    var body: some View {
        Button(action: { currentTab = tab }) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                Text(tab.title)
                    .font(.system(size: 13, weight: .medium))
                
                if requiresPro {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.orange)
                }
            }
            .foregroundColor(currentTab == tab ? .accentColor : .primary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Feature Locked View

struct FeatureLockedView: View {
    let feature: String
    let onUpgrade: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("\(feature) is a Pro feature")
                .font(.title2.bold())
            
            Text("Upgrade to Pro to unlock \(feature.lowercased()) and all other premium features.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Upgrade to Pro") {
                onUpgrade()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Button("Start Free Trial") {
                SubscriptionManager.shared.startTrial()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Visual effect blur for modern macOS look
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// Split view with three resizable panels
struct ThreePanelSplitView: NSViewRepresentable {
    let clipboardView: AnyView
    let filesView: AnyView
    let notesView: AnyView
    let selectedTab: PanelState.PanelTab
    
    class Coordinator: NSObject, NSSplitViewDelegate {
        func splitViewDidResizeSubviews(_ notification: Notification) {
            guard let splitView = notification.object as? NSSplitView else { return }
            
            // Save divider positions
            let positions = splitView.arrangedSubviews.map { $0.frame.width }
            UserDefaults.standard.set(positions, forKey: "TrayMe.DividerPositions")
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeNSView(context: Context) -> NSSplitView {
        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = context.coordinator
        
        // Create three hosting views
        let clipboardHosting = NSHostingView(rootView: clipboardView)
        let filesHosting = NSHostingView(rootView: filesView)
        let notesHosting = NSHostingView(rootView: notesView)
        
        // Add views to split view
        splitView.addArrangedSubview(clipboardHosting)
        splitView.addArrangedSubview(filesHosting)
        splitView.addArrangedSubview(notesHosting)
        
        // Restore saved positions or use equal proportions
        if let savedPositions = UserDefaults.standard.array(forKey: "TrayMe.DividerPositions") as? [CGFloat],
           savedPositions.count == 3 {
            // Restore saved widths
            DispatchQueue.main.async {
                for (index, width) in savedPositions.enumerated() {
                    if index < splitView.arrangedSubviews.count {
                        let subview = splitView.arrangedSubviews[index]
                        subview.widthAnchor.constraint(equalToConstant: width).isActive = false
                        splitView.setPosition(savedPositions.prefix(index + 1).reduce(0, +), ofDividerAt: index)
                    }
                }
            }
        }
        
        // Set equal proportions initially
        splitView.setHoldingPriority(.init(250), forSubviewAt: 0)
        splitView.setHoldingPriority(.init(250), forSubviewAt: 1)
        splitView.setHoldingPriority(.init(250), forSubviewAt: 2)
        
        return splitView
    }
    
    func updateNSView(_ nsView: NSSplitView, context: Context) {
        // Update background highlight based on selected tab
        for (index, subview) in nsView.arrangedSubviews.enumerated() {
            let shouldHighlight = (index == 0 && selectedTab == .clipboard) ||
                                  (index == 1 && selectedTab == .files) ||
                                  (index == 2 && selectedTab == .notes)
            
            if shouldHighlight {
                subview.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.05).cgColor
            } else {
                subview.layer?.backgroundColor = NSColor.clear.cgColor
            }
            subview.wantsLayer = true
        }
    }
}
