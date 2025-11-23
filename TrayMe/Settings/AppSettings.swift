//
//  AppSettings.swift
//  TrayMe
//

import SwiftUI
internal import Combine

class AppSettings: ObservableObject {
    @Published var enableMouseActivation = true
    @Published var enableHotkeyActivation = true
    @Published var hotkeyModifiers = "cmd+shift"
    @Published var hotkeyKey = "U"
    
    @Published var clipboardMaxHistory = 100
    @Published var ignorePasswordManagers = true
    @Published var clipboardEnabled = true
    
    @Published var filesMaxStorage = 50
    @Published var filesEnabled = true
    
    @Published var notesEnabled = true
    @Published var notesSyncWithiCloud = false
    
    @Published var panelWidth: Double = 900
    @Published var panelHeight: Double = 400
    @Published var defaultTab = "clipboard"
    
    init() {
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
    }
    
    func save() {
        UserDefaults.standard.set(enableMouseActivation, forKey: "enableMouseActivation")
        UserDefaults.standard.set(enableHotkeyActivation, forKey: "enableHotkeyActivation")
        UserDefaults.standard.set(hotkeyModifiers, forKey: "hotkeyModifiers")
        UserDefaults.standard.set(hotkeyKey, forKey: "hotkeyKey")
        UserDefaults.standard.set(clipboardMaxHistory, forKey: "clipboardMaxHistory")
        UserDefaults.standard.set(ignorePasswordManagers, forKey: "ignorePasswordManagers")
        UserDefaults.standard.set(clipboardEnabled, forKey: "clipboardEnabled")
        UserDefaults.standard.set(filesMaxStorage, forKey: "filesMaxStorage")
        UserDefaults.standard.set(filesEnabled, forKey: "filesEnabled")
        UserDefaults.standard.set(notesEnabled, forKey: "notesEnabled")
        UserDefaults.standard.set(notesSyncWithiCloud, forKey: "notesSyncWithiCloud")
        UserDefaults.standard.set(panelWidth, forKey: "panelWidth")
        UserDefaults.standard.set(panelHeight, forKey: "panelHeight")
        UserDefaults.standard.set(defaultTab, forKey: "defaultTab")
    }
}

