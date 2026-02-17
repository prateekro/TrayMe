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
    private var mouseUpMonitor: Any?
    
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
        
        // Position at top center of screen
        positionAtTopOfScreen()
        
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
        }
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
                        self.hide()
                    }
                }
            }
        }
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
                
                if delta < -5 {
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
                
                if delta < -5 {
                    self.hide()
                }
            }
        }
    }
    
    func setupDragMonitor() {
        // Monitor for drags globally to prevent closing during drag operations
        dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] event in
            guard let self = self, self.isVisible else { return }
            
            // If we detect a drag while panel is visible, set dragging state
            if !self.isDragging {
                self.isDragging = true
            }
        }
        
        // Also monitor for mouse up to reset drag state — store reference to avoid leak
        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
            guard let self = self else { return }
            
            if self.isDragging {
                // Delay reset to ensure drop completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    self?.isDragging = false
                }
            }
        }
    }
    
    private func setupContent() {
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
    }
    
    func positionAtTopOfScreen() {
        // Use the screen the mouse is on for better multi-monitor support
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main
        guard let screen = screen else { return }
        
        let screenFrame = screen.frame
        
        // Full screen width
        let panelWidth: CGFloat = screenFrame.width
        // 40% of screen height
        let panelHeight: CGFloat = screenFrame.height * 0.40
        
        // Start from left edge of the screen
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
        
        positionAtTopOfScreen()
        
        guard let screen = self.screen ?? NSScreen.main else { return }
        
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
            if !self.isDragging {
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
    }
    
    func hide() {
        guard let screen = self.screen ?? NSScreen.main else { return }
        
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
        // Clean up all event monitors
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = scrollOutsideMonitorLocal {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = scrollOutsideMonitorGlobal {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = dragMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = mouseUpMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
