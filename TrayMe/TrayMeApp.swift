//
//  TrayMeApp.swift
//  TrayMe - Unclutter Clone
//
//  A productivity app with clipboard manager, files hub, and quick notes
//

import SwiftUI
import AppKit

@main
struct TrayMeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Hidden main window - we'll use a custom panel
        Settings {
            SettingsView()
                .environmentObject(appDelegate.appSettings)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var mainPanel: MainPanel?
    var mouseTracker: MouseTracker?
    var statusBarItem: NSStatusItem?
    var localEventMonitor: Any?
    var globalEventMonitor: Any?
    
    // Shared managers
    let clipboardManager = ClipboardManager()
    let filesManager = FilesManager()
    let notesManager = NotesManager()
    let appSettings = AppSettings()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 TrayMe starting...")
        
        // Hide dock icon for menu bar app behavior
        NSApp.setActivationPolicy(.accessory)
        
        // Create status bar item
        setupStatusBar()
        print("✅ Status bar created")
        
        // Create main panel with shared managers
        mainPanel = MainPanel(
            clipboardManager: clipboardManager,
            filesManager: filesManager,
            notesManager: notesManager,
            appSettings: appSettings
        )
        print("✅ Main panel created")
        
        // Setup global hotkey first
        setupHotkey()
        
        // Request necessary permissions (must be AFTER hotkey setup)
        requestAccessibilityPermissions()
        
        // Setup mouse tracking for top-screen activation
        mouseTracker = MouseTracker { [weak self] in
            self?.togglePanel()
        }
        
        print("✅ TrayMe ready!")
    }
    
    func setupStatusBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusBarItem?.button {
            button.image = NSImage(systemSymbolName: "tray.2.fill", accessibilityDescription: "TrayMe")
            button.action = #selector(togglePanel)
            button.target = self
        }
    }
    
    @objc func togglePanel() {
        print("🔄 Toggle panel called")
        mainPanel?.toggle()
    }
    
    func setupHotkey() {
        print("⌨️ Setting up hotkey: Cmd+Ctrl+Shift+T")
        
        // Use NSEvent with flags matching
        let mask: NSEvent.ModifierFlags = [.command, .control, .shift]
        
        // Local monitor for when app has focus
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.command) && 
               event.modifierFlags.contains(.control) && 
               event.modifierFlags.contains(.shift) && 
               event.keyCode == 17 {
                print("🔥 Local hotkey triggered!")
                self?.togglePanel()
                return nil
            }
            return event
        }
        
        // Global monitor for when app is in background
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.command) && 
               event.modifierFlags.contains(.control) && 
               event.modifierFlags.contains(.shift) && 
               event.keyCode == 17 {
                print("🔥 Global hotkey triggered!")
                self?.togglePanel()
            }
        }
        
        print("✅ Hotkey registered (requires Accessibility permissions for global)")
    }
    
    func requestAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        if accessEnabled {
            print("✅ Accessibility permissions granted - global hotkey will work!")
        } else {
            print("⚠️  IMPORTANT: Accessibility permissions NOT granted")
            print("   The global hotkey (Cmd+Ctrl+Shift+T) will ONLY work when the app is in focus")
            print("")
            print("   To enable global hotkey (works even when app is hidden):")
            print("   1. Go to: System Settings > Privacy & Security > Accessibility")
            print("   2. Enable 'TrayMe'")
            print("   3. Restart the app")
            print("")
        }
    }
    
    deinit {
        // Clean up event monitors
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
