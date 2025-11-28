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
    
    // AI Features
    @Published var aiCategorizationEnabled = true {
        didSet { save() }
    }
    @Published var aiSuggestionsEnabled = true {
        didSet { save() }
    }
    
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
    
    // Analytics
    @Published var analyticsEnabled = true {
        didSet { 
            save()
            Task {
                await AnalyticsManager.shared.setEnabled(analyticsEnabled)
            }
        }
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
        if let saved = UserDefaults.standard.object(forKey: "aiCategorizationEnabled") as? Bool {
            aiCategorizationEnabled = saved
        }
        if let saved = UserDefaults.standard.object(forKey: "aiSuggestionsEnabled") as? Bool {
            aiSuggestionsEnabled = saved
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
        if let saved = UserDefaults.standard.object(forKey: "analyticsEnabled") as? Bool {
            analyticsEnabled = saved
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
        UserDefaults.standard.set(aiCategorizationEnabled, forKey: "aiCategorizationEnabled")
        UserDefaults.standard.set(aiSuggestionsEnabled, forKey: "aiSuggestionsEnabled")
        UserDefaults.standard.set(filesMaxStorage, forKey: "filesMaxStorage")
        UserDefaults.standard.set(filesEnabled, forKey: "filesEnabled")
        UserDefaults.standard.set(notesEnabled, forKey: "notesEnabled")
        UserDefaults.standard.set(notesSyncWithiCloud, forKey: "notesSyncWithiCloud")
        UserDefaults.standard.set(panelWidth, forKey: "panelWidth")
        UserDefaults.standard.set(panelHeight, forKey: "panelHeight")
        UserDefaults.standard.set(defaultTab, forKey: "defaultTab")
        UserDefaults.standard.set(analyticsEnabled, forKey: "analyticsEnabled")
    }
}