//
//  MainPanel.swift
//  TrayMe
//

import SwiftUI
import AppKit

class MainPanel: NSPanel {
    private var hostingView: NSView?
    private var clickOutsideMonitor: Any?
    private var scrollOutsideMonitorLocal: Any?
    private var scrollOutsideMonitorGlobal: Any?
    private var dragMonitor: Any?
    
    // Panel state for tab control
    let panelState = PanelState()
    
    // Track if we're in a drag operation
    private var isDragging = false
    
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
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        
        print("📦 Panel initialized")
        
        // Panel settings
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isFloatingPanel = true
        self.hidesOnDeactivate = false
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.styleMask.remove(.titled)
        self.standardWindowButton(.closeButton)?.isHidden = true
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true
        
        print("📦 Panel settings applied")
        
        // Position at top center of screen
        positionAtTopOfScreen()
        
        print("📦 Panel positioned")
        
        // Setup click outside to close
        setupClickOutsideMonitor()
        
        // Setup scroll down to close
        setupScrollOutsideMonitor()
        
        // Setup drag detection
        setupDragMonitor()
        
        // Initially hidden
        self.orderOut(nil)
        
        // Defer content setup to avoid layout recursion
        DispatchQueue.main.async { [weak self] in
            self?.setupContent()
            print("📦 Content setup complete")
        }
        
        print("✅ MainPanel created successfully")
    }
    
    // Override to allow panel to become key window for text editing
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return false
    }
    
    func setupClickOutsideMonitor() {
        // Monitor for clicks outside the panel
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.isVisible else { return }
            
            // Don't close if we're dragging
            if self.isDragging {
                print("👆 Click detected but dragging - ignoring")
                return
            }
            
            // Get screen location of click
            let screenLocation = NSEvent.mouseLocation
            
            // Check if click is outside panel bounds
            if !self.frame.contains(screenLocation) {
                // Delay closing to allow drag detection
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                    guard let self = self else { return }
                    
                    // Double-check we're not dragging
                    if !self.isDragging && self.isVisible {
                        print("👆 Click outside panel - closing")
                        self.hide()
                    } else {
                        print("👆 Click was start of drag - keeping panel open")
                    }
                }
            }
        }
        
        print("✅ Click outside monitor setup")
    }
    
    func setupScrollOutsideMonitor() {
        // Monitor for scroll down when panel is visible - LOCAL events
        scrollOutsideMonitorLocal = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self = self, self.isVisible else { return event }
            
            // Get mouse location
            let mouseLocation = NSEvent.mouseLocation
            
            // Check if mouse is outside the panel
            if !self.frame.contains(mouseLocation) {
                // Detect scroll down (negative delta)
                let delta = event.scrollingDeltaY
                
                if delta < -5 { // Small threshold to avoid accidental closes
                    print("📜 Scroll down outside panel - closing")
                    self.hide()
                }
            }
            
            return event
        }
        
        // Monitor for scroll down - GLOBAL events (when app not focused)
        scrollOutsideMonitorGlobal = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self = self, self.isVisible else { return }
            
            // Get mouse location
            let mouseLocation = NSEvent.mouseLocation
            
            // Check if mouse is outside the panel
            if !self.frame.contains(mouseLocation) {
                // Detect scroll down (negative delta)
                let delta = event.scrollingDeltaY
                
                if delta < -5 { // Small threshold to avoid accidental closes
                    print("📜 Scroll down outside panel (global) - closing")
                    self.hide()
                }
            }
        }
        
        print("✅ Scroll outside monitor setup (local + global)")
    }
    
    func setupDragMonitor() {
        // Monitor for drags globally to prevent closing during drag operations
        dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] event in
            guard let self = self, self.isVisible else { return }
            
            // If we detect a drag while panel is visible, set dragging state
            if !self.isDragging {
                print("🎯 Drag detected - preventing panel close")
                self.isDragging = true
            }
        }
        
        // Also monitor for mouse up to reset drag state
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
            guard let self = self else { return }
            
            if self.isDragging {
                // Delay reset to ensure drop completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.isDragging = false
                    print("🎯 Drag ended - re-enabling panel close")
                }
            }
        }
        
        print("✅ Drag monitor setup")
    }
    
    private func setupContent() {
        print("🎨 Setting up SwiftUI content...")
        
        // Create MainPanelView with shared managers
        let contentView = MainPanelView()
            .environmentObject(clipboardManager)
            .environmentObject(filesManager)
            .environmentObject(notesManager)
            .environmentObject(appSettings)
            .environmentObject(panelState)
        
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
        // Use full frame to include menu bar area
        let screenFrame = screen.frame
        
        // Full screen width
        let panelWidth: CGFloat = screenFrame.width
        // 40% of screen height
        let panelHeight: CGFloat = screenFrame.height * 0.40
        
        // Start from left edge
        let x = screenFrame.minX
        // Position at absolute top of screen (including menu bar)
        let y = screenFrame.maxY - panelHeight
        
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
        // Don't show if already visible
        guard !self.isVisible else { return }
        
        guard let screen = NSScreen.main else { return }
        
        positionAtTopOfScreen()
        
        // Slide down animation from above screen
        let currentFrame = self.frame
        let targetY = currentFrame.origin.y
        let panelWidth = currentFrame.width
        let panelHeight = currentFrame.height
        
        // Start position: completely above the screen
        var startFrame = currentFrame
        startFrame.origin.y = screen.frame.maxY
        self.setFrame(startFrame, display: false)
        
        self.makeKeyAndOrderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().setFrame(NSRect(x: currentFrame.origin.x, y: targetY, width: panelWidth, height: panelHeight), display: true)
        } completionHandler: {
            // After animation, focus notes if not dragging files
            print("🎬 Animation complete. isDragging: \(self.isDragging)")
            if !self.isDragging {
                print("🔔 Posting FocusNotes notification")
                NotificationCenter.default.post(name: .focusNotes, object: nil)
            }
        }
    }
    
    func showWithFilesTab() {
        // Switch to files tab
        panelState.selectedTab = .files
        // Show the panel
        show()
    }
    
    func setDragging(_ dragging: Bool) {
        isDragging = dragging
        print("🎯 Dragging state: \(dragging)")
    }
    
    func hide() {
        guard let screen = NSScreen.main else { return }
        
        // Close Quick Look if it's open
        NotificationCenter.default.post(name: .mainPanelWillHide, object: nil)
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            
            // Slide up to above the screen (including menu bar)
            var frame = self.frame
            frame.origin.y = screen.frame.maxY
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
        
        // Clean up scroll monitors
        if let monitor = scrollOutsideMonitorLocal {
            NSEvent.removeMonitor(monitor)
        }
        
        if let monitor = scrollOutsideMonitorGlobal {
            NSEvent.removeMonitor(monitor)
        }
        
        // Clean up drag monitor
        if let monitor = dragMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
