//
//  MainPanel.swift
//  TrayMe
//

import SwiftUI
import AppKit

class MainPanel: NSPanel {
    private var hostingView: NSView?
    private var clickOutsideMonitor: Any?
    
    // Store references to managers
    private let clipboardManager: ClipboardManager
    private let filesManager: FilesManager
    private let notesManager: NotesManager
    private let appSettings: AppSettings
    
    init(clipboardManager: ClipboardManager,
         filesManager: FilesManager,
         notesManager: NotesManager,
         appSettings: AppSettings) {
        
        print("📦 Creating MainPanel...")
        
        // Store managers
        self.clipboardManager = clipboardManager
        self.filesManager = filesManager
        self.notesManager = notesManager
        self.appSettings = appSettings
        
        // Panel configuration
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 400),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        print("📦 Panel initialized")
        
        // Panel settings
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false
        self.title = "TrayMe"
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        
        print("📦 Panel settings applied")
        
        // Position at top center of screen
        positionAtTopOfScreen()
        
        print("📦 Panel positioned")
        
        // Setup click outside to close
        setupClickOutsideMonitor()
        
        // Initially hidden
        self.orderOut(nil)
        
        // Defer content setup to avoid layout recursion
        DispatchQueue.main.async { [weak self] in
            self?.setupContent()
            print("📦 Content setup complete")
        }
        
        print("✅ MainPanel created successfully")
    }
    
    func setupClickOutsideMonitor() {
        // Monitor for clicks outside the panel
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.isVisible else { return }
            
            // Get screen location of click
            let screenLocation = NSEvent.mouseLocation
            
            // Check if click is outside panel bounds
            if !self.frame.contains(screenLocation) {
                print("👆 Click outside panel - closing")
                self.hide()
            }
        }
        
        print("✅ Click outside monitor setup")
    }
    
    private func setupContent() {
        print("🎨 Setting up SwiftUI content...")
        
        // Create MainPanelView with shared managers
        let contentView = MainPanelView()
            .environmentObject(clipboardManager)
            .environmentObject(filesManager)
            .environmentObject(notesManager)
            .environmentObject(appSettings)
        
        // Wrap in hosting view
        let hosting = NSHostingView(rootView: contentView)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        
        // Add to panel
        guard let contentView = self.contentView else { return }
        contentView.addSubview(hosting)
        
        // Use constraints instead of autoresizing mask
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: contentView.topAnchor),
            hosting.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            hosting.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        
        self.hostingView = hosting
        
        print("🎨 SwiftUI content added")
    }
    
    func positionAtTopOfScreen() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        
        let panelWidth: CGFloat = 900
        let panelHeight: CGFloat = 400
        
        let x = screenFrame.midX - (panelWidth / 2)
        let y = screenFrame.maxY - panelHeight - 10 // 10px from top
        
        self.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
    }
    
    func toggle() {
        if self.isVisible {
            hide()
        } else {
            show()
        }
    }
    
    func show() {
        positionAtTopOfScreen()
        
        // Slide down animation
        let currentFrame = self.frame
        let targetY = currentFrame.origin.y
        let panelWidth = currentFrame.width
        let panelHeight = currentFrame.height
        
        var startFrame = currentFrame
        startFrame.origin.y = NSScreen.main!.visibleFrame.maxY
        self.setFrame(startFrame, display: false)
        
        self.makeKeyAndOrderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().setFrame(NSRect(x: currentFrame.origin.x, y: targetY, width: panelWidth, height: panelHeight), display: true)
        }
    }
    
    func hide() {
        guard let screen = NSScreen.main else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            
            var frame = self.frame
            frame.origin.y = screen.visibleFrame.maxY
            self.animator().setFrame(frame, display: true)
        }) {
            self.orderOut(nil)
        }
    }
    
    deinit {
        // Clean up click monitor
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
