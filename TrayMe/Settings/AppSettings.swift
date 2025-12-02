//
//  AppSettings.swift
//  TrayMe
//

import SwiftUI
import Combine

class AppSettings: ObservableObject {
    @Published var enableMouseActivation = true {
        didSet { save() }
    }
    @Published var enableHotkeyActivation = true {
        didSet { save() }
    }
    @Published var hotkeyModifiers = "cmd+shift" {
        didSet { save() }
    }
    @Published var hotkeyKey = "U" {
        didSet { save() }
    }
    
    @Published var clipboardMaxHistory = 100 {
        didSet { save() }
    }
    @Published var ignorePasswordManagers = true {
        didSet { save() }
    }
    @Published var clipboardEnabled = true {
        didSet { save() }
    }
    
    /// List of excluded app bundle identifiers - clipboard won't be tracked when copying from these apps
    @Published var excludedAppBundleIds: Set<String> = [] {
        didSet { save() }
    }
    
    /// Default excluded apps (password managers and sensitive apps)
    static let defaultExcludedApps: [ExcludedApp] = [
        ExcludedApp(bundleId: "com.agilebits.onepassword7", name: "1Password 7"),
        ExcludedApp(bundleId: "com.1password.1password", name: "1Password 8"),
        ExcludedApp(bundleId: "com.lastpass.LastPass", name: "LastPass"),
        ExcludedApp(bundleId: "com.bitwarden.desktop", name: "Bitwarden"),
        ExcludedApp(bundleId: "com.dashlane.Dashlane", name: "Dashlane"),
        ExcludedApp(bundleId: "com.apple.keychainaccess", name: "Keychain Access"),
        ExcludedApp(bundleId: "org.keepassxc.keepassxc", name: "KeePassXC"),
        ExcludedApp(bundleId: "com.enpass.Enpass", name: "Enpass"),
        ExcludedApp(bundleId: "com.nordpass.NordPass", name: "NordPass"),
        ExcludedApp(bundleId: "com.roboform.roboform", name: "RoboForm"),
    ]
    
    @Published var filesMaxStorage = 50 {
        didSet { save() }
    }
    @Published var filesEnabled = true {
        didSet { save() }
    }
    
    @Published var notesEnabled = true {
        didSet { save() }
    }
    @Published var notesSyncWithiCloud = false {
        didSet { save() }
    }
    
    @Published var panelWidth: Double = 900 {
        didSet { save() }
    }
    @Published var panelHeight: Double = 400 {
        didSet { save() }
    }
    @Published var defaultTab = "clipboard" {
        didSet { save() }
    }
    
    private var isLoading = false
    
    init() {
        isLoading = true
        // Load from UserDefaults if available
        if let saved = UserDefaults.standard.object(forKey: "enableMouseActivation") as? Bool {
            enableMouseActivation = saved
        }
        if let saved = UserDefaults.standard.object(forKey: "enableHotkeyActivation") as? Bool {
            enableHotkeyActivation = saved
        }
        if let saved = UserDefaults.standard.string(forKey: "hotkeyModifiers") {
            hotkeyModifiers = saved
        }
        if let saved = UserDefaults.standard.string(forKey: "hotkeyKey") {
            hotkeyKey = saved
        }
        if let saved = UserDefaults.standard.object(forKey: "clipboardMaxHistory") as? Int {
            clipboardMaxHistory = saved
        }
        if let saved = UserDefaults.standard.object(forKey: "ignorePasswordManagers") as? Bool {
            ignorePasswordManagers = saved
        }
        if let saved = UserDefaults.standard.object(forKey: "clipboardEnabled") as? Bool {
            clipboardEnabled = saved
        }
        if let savedArray = UserDefaults.standard.array(forKey: "excludedAppBundleIds") as? [String] {
            excludedAppBundleIds = Set(savedArray)
        }
        if let saved = UserDefaults.standard.object(forKey: "filesMaxStorage") as? Int {
            filesMaxStorage = saved
        }
        if let saved = UserDefaults.standard.object(forKey: "filesEnabled") as? Bool {
            filesEnabled = saved
        }
        if let saved = UserDefaults.standard.object(forKey: "notesEnabled") as? Bool {
            notesEnabled = saved
        }
        if let saved = UserDefaults.standard.object(forKey: "notesSyncWithiCloud") as? Bool {
            notesSyncWithiCloud = saved
        }
        if let saved = UserDefaults.standard.object(forKey: "panelWidth") as? Double {
            panelWidth = saved
        }
        if let saved = UserDefaults.standard.object(forKey: "panelHeight") as? Double {
            panelHeight = saved
        }
        if let saved = UserDefaults.standard.string(forKey: "defaultTab") {
            defaultTab = saved
        }
        isLoading = false
    }
    
    func save() {
        // Don't save during initial load
        guard !isLoading else { return }
        
        UserDefaults.standard.set(enableMouseActivation, forKey: "enableMouseActivation")
        UserDefaults.standard.set(enableHotkeyActivation, forKey: "enableHotkeyActivation")
        UserDefaults.standard.set(hotkeyModifiers, forKey: "hotkeyModifiers")
        UserDefaults.standard.set(hotkeyKey, forKey: "hotkeyKey")
        UserDefaults.standard.set(clipboardMaxHistory, forKey: "clipboardMaxHistory")
        UserDefaults.standard.set(ignorePasswordManagers, forKey: "ignorePasswordManagers")
        UserDefaults.standard.set(clipboardEnabled, forKey: "clipboardEnabled")
        UserDefaults.standard.set(Array(excludedAppBundleIds), forKey: "excludedAppBundleIds")
        UserDefaults.standard.set(filesMaxStorage, forKey: "filesMaxStorage")
        UserDefaults.standard.set(filesEnabled, forKey: "filesEnabled")
        UserDefaults.standard.set(notesEnabled, forKey: "notesEnabled")
        UserDefaults.standard.set(notesSyncWithiCloud, forKey: "notesSyncWithiCloud")
        UserDefaults.standard.set(panelWidth, forKey: "panelWidth")
        UserDefaults.standard.set(panelHeight, forKey: "panelHeight")
        UserDefaults.standard.set(defaultTab, forKey: "defaultTab")
    }
    
    /// Check if an app's clipboard content should be excluded
    func isAppExcluded(bundleId: String?) -> Bool {
        guard let bundleId = bundleId else { return false }
        return excludedAppBundleIds.contains(bundleId)
    }
    
    /// Add an app to the exclusion list
    func excludeApp(_ bundleId: String) {
        excludedAppBundleIds.insert(bundleId)
    }
    
    /// Remove an app from the exclusion list
    func includeApp(_ bundleId: String) {
        excludedAppBundleIds.remove(bundleId)
    }
    
    /// Add all default password managers to exclusion list
    func excludeAllDefaultApps() {
        for app in Self.defaultExcludedApps {
            excludedAppBundleIds.insert(app.bundleId)
        }
    }
}

/// Represents an app that can be excluded from clipboard tracking
struct ExcludedApp: Identifiable, Hashable {
    let bundleId: String
    let name: String
    
    var id: String { bundleId }
}