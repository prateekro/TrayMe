//
//  SettingsView.swift
//  TrayMe
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .environmentObject(settings)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
            
            ClipboardSettingsView()
                .environmentObject(settings)
                .tabItem {
                    Label("Clipboard", systemImage: "doc.on.clipboard")
                }
            
            FilesSettingsView()
                .environmentObject(settings)
                .tabItem {
                    Label("Files", systemImage: "folder")
                }
            
            NotesSettingsView()
                .environmentObject(settings)
                .tabItem {
                    Label("Notes", systemImage: "note.text")
                }
            
            SecuritySettingsView()
                .tabItem {
                    Label("Security", systemImage: "lock.shield")
                }
            
            SubscriptionSettingsView()
                .tabItem {
                    Label("Subscription", systemImage: "star")
                }
        }
        .frame(width: 550, height: 500)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        Form {
            Section(header: Text("Activation").font(.headline)) {
                Toggle("Enable mouse activation at top of screen", isOn: $settings.enableMouseActivation)
                    .help("Move mouse to top of screen to show TrayMe")
                
                Toggle("Enable hotkey activation", isOn: $settings.enableHotkeyActivation)
                    .help("Use keyboard shortcut to toggle TrayMe")
                
                HStack {
                    Text("Hotkey:")
                    TextField("Modifiers", text: $settings.hotkeyModifiers)
                        .frame(width: 100)
                    Text("+")
                    TextField("Key", text: $settings.hotkeyKey)
                        .frame(width: 50)
                }
                .disabled(!settings.enableHotkeyActivation)
            }
            
            Section(header: Text("Appearance").font(.headline)) {
                Picker("Default tab:", selection: $settings.defaultTab) {
                    Text("Clipboard").tag("clipboard")
                    Text("Files").tag("files")
                    Text("Notes").tag("notes")
                }
                .pickerStyle(.radioGroup)
                
                HStack {
                    Text("Panel size:")
                    Slider(value: $settings.panelWidth, in: 600...1400, step: 50)
                    Text("\(Int(settings.panelWidth))px")
                }
            }
            
            Section(header: Text("About").font(.headline)) {
                HStack {
                    Text("Version:")
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("TrayMe - Unclutter Clone")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
    }
}

struct ClipboardSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @StateObject private var aiEngine = AIClipboardEngine.shared
    
    var body: some View {
        Form {
            Section(header: Text("Clipboard Manager").font(.headline)) {
                Toggle("Enable clipboard manager", isOn: $settings.clipboardEnabled)
                
                HStack {
                    Text("Max history items:")
                    Slider(value: Binding(
                        get: { Double(settings.clipboardMaxHistory) },
                        set: { settings.clipboardMaxHistory = Int($0) }
                    ), in: 10...500, step: 10)
                    Text("\(settings.clipboardMaxHistory)")
                }
                .disabled(!settings.clipboardEnabled)
                
                Toggle("Ignore password managers", isOn: $settings.ignorePasswordManagers)
                    .help("Don't track clipboard when copying from 1Password, LastPass, etc.")
                    .disabled(!settings.clipboardEnabled)
            }
            
            Section(header: Text("AI Features").font(.headline)) {
                Toggle("Enable smart categorization", isOn: $settings.aiCategorizationEnabled)
                    .help("Automatically categorize clipboard items")
                
                Toggle("Enable context-aware suggestions", isOn: $settings.aiSuggestionsEnabled)
                    .help("Get smart suggestions based on your current app")
                
                HStack {
                    Text("AI cache size:")
                    Text("\(aiEngine.cacheSize) items")
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Clear Cache") {
                        aiEngine.clearCache()
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            Section(header: Text("Privacy").font(.headline)) {
                Text("Clipboard data is stored locally on your Mac")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("No data is sent to external servers")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("AI processing happens entirely on-device")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
    }
}

struct FilesSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        Form {
            Section(header: Text("Files Hub").font(.headline)) {
                Toggle("Enable files hub", isOn: $settings.filesEnabled)
                
                HStack {
                    Text("Max stored files:")
                    Slider(value: Binding(
                        get: { Double(settings.filesMaxStorage) },
                        set: { settings.filesMaxStorage = Int($0) }
                    ), in: 10...100, step: 5)
                    Text("\(settings.filesMaxStorage)")
                }
                .disabled(!settings.filesEnabled)
            }
            
            Section(header: Text("Storage").font(.headline)) {
                Text("Files are referenced, not copied")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Moving or deleting the original file will break the reference")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
    }
}

struct NotesSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        Form {
            Section(header: Text("Quick Notes").font(.headline)) {
                Toggle("Enable quick notes", isOn: $settings.notesEnabled)
                
                Toggle("Sync with iCloud", isOn: $settings.notesSyncWithiCloud)
                    .help("Sync notes across your Apple devices")
                    .disabled(!settings.notesEnabled || true) // iCloud sync not yet implemented
            }
            
            Section(header: Text("Storage").font(.headline)) {
                Text("Notes are stored locally in Application Support")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
    }
}

// MARK: - Security Settings

struct SecuritySettingsView: View {
    @StateObject private var securityManager = SecurityManager.shared
    @StateObject private var biometricAuth = BiometricAuth()
    
    var body: some View {
        Form {
            Section(header: Text("Authentication").font(.headline)) {
                HStack {
                    Image(systemName: biometricAuth.biometricIcon)
                        .foregroundColor(.accentColor)
                    Text(biometricAuth.biometricName)
                    Spacer()
                    Text(biometricAuth.isAvailable ? "Available" : "Not Available")
                        .foregroundColor(biometricAuth.isAvailable ? .green : .secondary)
                }
                
                Toggle("Require authentication for sensitive clips", isOn: $securityManager.requireAuthForSensitive)
                    .help("Lock sensitive content like passwords and API keys")
            }
            
            Section(header: Text("Auto-Lock").font(.headline)) {
                Picker("Auto-lock after inactivity:", selection: $securityManager.autoLockMinutes) {
                    Text("Disabled").tag(0)
                    Text("1 minute").tag(1)
                    Text("5 minutes").tag(5)
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                    Text("1 hour").tag(60)
                }
                
                Toggle("Lock on sleep", isOn: .constant(true))
                    .disabled(true)
                    .help("Always locks when Mac goes to sleep")
                
                Toggle("Lock on screen lock", isOn: .constant(true))
                    .disabled(true)
                    .help("Always locks when screen is locked")
            }
            
            Section(header: Text("Status").font(.headline)) {
                HStack {
                    Text("Current status:")
                    Spacer()
                    if securityManager.isUnlocked {
                        Label("Unlocked", systemImage: "lock.open.fill")
                            .foregroundColor(.green)
                    } else {
                        Label("Locked", systemImage: "lock.fill")
                            .foregroundColor(.orange)
                    }
                }
                
                if securityManager.isUnlocked {
                    Button("Lock Now") {
                        securityManager.lock()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Unlock") {
                        Task {
                            await securityManager.authenticate()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(20)
    }
}

// MARK: - Subscription Settings

struct SubscriptionSettingsView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showUpgradeSheet = false
    
    var body: some View {
        Form {
            Section(header: Text("Current Plan").font(.headline)) {
                HStack {
                    VStack(alignment: .leading) {
                        HStack {
                            Text(subscriptionManager.currentTier.displayName)
                                .font(.title2.bold())
                            
                            if subscriptionManager.isTrialing {
                                Text("TRIAL")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange)
                                    .cornerRadius(4)
                            }
                        }
                        
                        if subscriptionManager.isTrialing {
                            Text("\(subscriptionManager.trialDaysRemaining) days remaining")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Spacer()
                    
                    if subscriptionManager.currentTier == .free {
                        Button("Upgrade") {
                            showUpgradeSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            
            Section(header: Text("Usage").font(.headline)) {
                FullUsageOverviewView()
            }
            
            Section(header: Text("Features").font(.headline)) {
                FeatureRow(name: "AI Features", isAvailable: subscriptionManager.isFeatureAvailable(.ai))
                FeatureRow(name: "Text Snippets", isAvailable: subscriptionManager.isFeatureAvailable(.snippets))
                FeatureRow(name: "Analytics Dashboard", isAvailable: subscriptionManager.isFeatureAvailable(.analytics))
                FeatureRow(name: "Security Features", isAvailable: subscriptionManager.isFeatureAvailable(.security))
                FeatureRow(name: "iCloud Sync", isAvailable: subscriptionManager.isFeatureAvailable(.sync))
            }
            
            Section {
                Button("Restore Purchases") {
                    Task {
                        await subscriptionManager.restorePurchases()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradeView()
        }
    }
}

struct FeatureRow: View {
    let name: String
    let isAvailable: Bool
    
    var body: some View {
        HStack {
            Text(name)
            Spacer()
            Image(systemName: isAvailable ? "checkmark.circle.fill" : "lock.fill")
                .foregroundColor(isAvailable ? .green : .secondary)
        }
    }
}
