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
    var dragDetector: DragDetectorWindow?
    var statusBarItem: NSStatusItem?
    var localEventMonitor: Any?
    var globalEventMonitor: Any?
    
    // Shared managers
    let clipboardManager = ClipboardManager()
    let filesManager = FilesManager()
    let notesManager = NotesManager()
    let appSettings = AppSettings()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let appStartTime = CFAbsoluteTimeGetCurrent()
        print("🚀 TrayMe starting...")
        
        // Hide dock icon for menu bar app behavior
        NSApp.setActivationPolicy(.accessory)
        
        // Create status bar item
        let statusBarTime = CFAbsoluteTimeGetCurrent()
        setupStatusBar()
        print("✅ Status bar created (\(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - statusBarTime))s)")
        
        // Create main panel with shared managers
        let panelStartTime = CFAbsoluteTimeGetCurrent()
        mainPanel = MainPanel(
            clipboardManager: clipboardManager,
            filesManager: filesManager,
            notesManager: notesManager,
            appSettings: appSettings
        )
        print("✅ Main panel created (\(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - panelStartTime))s)")
        
        // Setup global hotkey first
        setupHotkey()
        
        // Request necessary permissions (must be AFTER hotkey setup)
        requestAccessibilityPermissions()
        
        // Setup mouse tracking for top-screen activation
        mouseTracker = MouseTracker { [weak self] in
            // Show panel when scrolling up at top
            self?.mainPanel?.show()
        }
        
        // Setup drag detector window
        dragDetector = DragDetectorWindow(
            dragStartCallback: { [weak self] in
                // Mark panel as dragging to prevent click-outside close
                self?.mainPanel?.setDragging(true)
            },
            dragEndCallback: { [weak self] in
                // Reset dragging state
                self?.mainPanel?.setDragging(false)
            },
            dragActivateCallback: { [weak self] in
                // Show panel with Files tab when file is dragged to top
                self?.mainPanel?.showWithFilesTab()
            }
        )
        
        print("✅ TrayMe ready! (Total: \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - appStartTime))s)")
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
        print("⌨️ Setting up hotkey: Cmd+Ctrl+Shift+U")
        
        // Local monitor for when app has focus
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.command) && 
               event.modifierFlags.contains(.control) && 
               event.modifierFlags.contains(.shift) && 
               event.keyCode == 32 { // keyCode 32 = U
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
               event.keyCode == 32 { // keyCode 32 = U
                print("🔥 Global hotkey triggered!")
                self?.togglePanel()
            }
        }
        
        print("✅ Hotkey registered (requires Accessibility permissions for global)")
    }
    
    func requestAccessibilityPermissions() {
        // Only check permissions, don't request yet
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        if accessEnabled {
            print("✅ Accessibility permissions granted!")
            print("   ✓ Global hotkey (Cmd+Ctrl+Shift+U) will work system-wide")
        } else {
            print("ℹ️  Accessibility permissions not granted (optional)")
            print("   • Global hotkey will only work when app is focused")
            print("   • Mouse scroll-down gesture works WITHOUT permissions ✨")
            print("")
            print("   To enable global hotkey (optional):")
            print("   Go to: System Settings > Privacy & Security > Accessibility")
            print("   Enable 'TrayMe' and restart the app")
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
