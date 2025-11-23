//
//  MouseTracker.swift
//  TrayMe
//
//  Detects when mouse is in menu bar area and user scrolls up to activate panel
//

import AppKit
import CoreGraphics

class MouseTracker {
    private var scrollMonitorLocal: Any?
    private var scrollMonitorGlobal: Any?
    private var invisibleWindow: NSWindow?
    private let activationCallback: () -> Void
    
    private var mouseAtTop = false
    private var scrollDelta: CGFloat = 0
    private let scrollThreshold: CGFloat = 20 // Amount of scroll needed to trigger
    
    init(activationCallback: @escaping () -> Void) {
        self.activationCallback = activationCallback
        startTracking()
    }
    
    func startTracking() {
        print("🔍 Starting MouseTracker...")
        
        guard let screen = NSScreen.main else {
            print("   ⚠️ No main screen found")
            return
        }
        
        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        
        // Calculate menu bar height
        let menuBarHeight = screenFrame.maxY - visibleFrame.maxY
        
        print("   📏 Screen: \(Int(screenFrame.width))x\(Int(screenFrame.height))")
        print("   📏 Visible frame top: \(Int(visibleFrame.maxY))")
        print("   📏 Menu bar height: \(Int(menuBarHeight))px")
        
        // Create tracking window that covers EXACTLY the menu bar area
        let trackingFrame = NSRect(
            x: screenFrame.origin.x,
            y: visibleFrame.maxY, // Start where visible frame ends (menu bar starts)
            width: screenFrame.width,
            height: menuBarHeight
        )
        
        print("   📏 Tracking window: x=\(Int(trackingFrame.origin.x)) y=\(Int(trackingFrame.origin.y)) w=\(Int(trackingFrame.width)) h=\(Int(trackingFrame.height))")
        
        // Create borderless, transparent window
        let window = NSWindow(
            contentRect: trackingFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = false // Must receive events for tracking
        window.level = .statusBar // Same level as menu bar
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        window.acceptsMouseMovedEvents = true
        
        // Create tracking view
        let trackingView = TrackingView(frame: window.contentView!.bounds)
        trackingView.onMouseEntered = { [weak self] in
            self?.mouseAtTop = true
            self?.scrollDelta = 0
            print("🖱️ Mouse ENTERED menu bar area")
        }
        trackingView.onMouseExited = { [weak self] in
            self?.mouseAtTop = false
            self?.scrollDelta = 0
            print("🖱️ Mouse LEFT menu bar area")
        }
        window.contentView = trackingView
        
        // Create tracking area covering entire window
        let trackingArea = NSTrackingArea(
            rect: trackingView.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: trackingView,
            userInfo: nil
        )
        trackingView.addTrackingArea(trackingArea)
        
        self.invisibleWindow = window
        window.orderFront(nil)
        
        // Monitor scroll events - both local and global
        scrollMonitorLocal = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScrollEvent(event)
            return event
        }
        
        scrollMonitorGlobal = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScrollEvent(event)
        }
        
        print("✅ Mouse tracker started!")
        print("   📍 Tracking ONLY in menu bar area")
        print("   📜 Scroll UP \(Int(scrollThreshold))px in menu bar to activate")
        print("   ✨ No Accessibility permissions required!")
    }
    
    private func handleScrollEvent(_ event: NSEvent) {
        // Get scroll delta (positive = scroll UP)
        let delta = event.scrollingDeltaY
        
        // Log all scroll events for debugging
        if abs(delta) > 0.5 {
            print("📜 Scroll: \(String(format: "%.1f", delta)) | In menu bar: \(mouseAtTop)")
        }
        
        // Only accumulate when mouse is in menu bar
        guard mouseAtTop else {
            scrollDelta = 0
            return
        }
        
        // Accumulate UPWARD scroll (positive values)
        if delta > 0 {
            scrollDelta += abs(delta)
            print("   ⬆️ Scroll UP accumulated: \(String(format: "%.1f", scrollDelta))/\(Int(scrollThreshold))")
            
            // Trigger when threshold reached
            if scrollDelta >= scrollThreshold {
                print("🎯 Threshold reached - activating panel!")
                scrollDelta = 0
                // Don't reset mouseAtTop - allow repeated activations without leaving menu bar
                activationCallback()
            }
        } else if delta < 0 {
            // Reset on downward scroll
            let oldDelta = scrollDelta
            scrollDelta = max(0, scrollDelta - abs(delta))
            if oldDelta > 0 {
                print("   ⬇️ Scroll DOWN - reset to: \(String(format: "%.1f", scrollDelta))")
            }
        }
    }
    
    func stopTracking() {
        if let monitor = scrollMonitorLocal {
            NSEvent.removeMonitor(monitor)
            scrollMonitorLocal = nil
        }
        
        if let monitor = scrollMonitorGlobal {
            NSEvent.removeMonitor(monitor)
            scrollMonitorGlobal = nil
        }
        
        if let window = invisibleWindow {
            window.close()
            invisibleWindow = nil
        }
        
        print("⏹️ Mouse tracker stopped")
    }
    
    deinit {
        stopTracking()
    }
}

// Custom view for tracking mouse entry/exit
private class TrackingView: NSView {
    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?
    
    override func mouseEntered(with event: NSEvent) {
        onMouseEntered?()
    }
    
    override func mouseExited(with event: NSEvent) {
        onMouseExited?()
    }
}
