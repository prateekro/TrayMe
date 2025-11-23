//
//  MouseTracker.swift
//  TrayMe
//
//  Detects when mouse is at top of screen and user scrolls up to activate panel
//

import AppKit
import CoreGraphics

class MouseTracker {
    private var scrollMonitorLocal: Any?
    private var scrollMonitorGlobal: Any?
    private var mouseMonitor: Any?
    private let activationCallback: () -> Void
    
    private var mouseAtTop = false
    private var scrollDelta: CGFloat = 0
    private let scrollThreshold: CGFloat = 20 // Amount of scroll needed to trigger
    private let topEdgeThreshold: CGFloat = 5 // Pixels from top to be considered "at top"
    
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
        
        print("   📏 Screen: \(Int(screenFrame.width))x\(Int(screenFrame.height))")
        print("   📏 Detection: Top \(Int(topEdgeThreshold))px of screen")
        
        // Monitor mouse movement globally
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            guard let self = self else { return }
            self.checkMousePosition()
        }
        
        // Also monitor locally
        NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            guard let self = self else { return event }
            self.checkMousePosition()
            return event
        }
        
        // Monitor scroll events - both local and global
        scrollMonitorLocal = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScrollEvent(event)
            return event
        }
        
        scrollMonitorGlobal = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScrollEvent(event)
        }
        
        // Note: leftMouseDragged only works for drags within our app
        // For external file drags, we need a drag destination view
        // This is implemented in FilesView with .onDrop()
        
        print("✅ Mouse tracker started!")
        print("   📍 Tracking when mouse at top \(Int(topEdgeThreshold))px of screen")
        print("   📜 Scroll UP \(Int(scrollThreshold))px to activate")
        print("   🗂️ Drag files over panel to drop them")
        print("   ✨ No Accessibility permissions required!")
    }
    
    private func checkMousePosition() {
        guard let screen = NSScreen.main else { return }
        
        let mouseLocation = NSEvent.mouseLocation
        let screenFrame = screen.frame
        
        // Check if mouse is at the very top of screen
        // NSEvent.mouseLocation has Y=0 at bottom, so top is screenFrame.maxY
        let isAtTop = mouseLocation.y >= screenFrame.maxY - topEdgeThreshold
        
        if isAtTop && !mouseAtTop {
            mouseAtTop = true
            scrollDelta = 0
            print("🖱️ Mouse at TOP of screen")
        } else if !isAtTop && mouseAtTop {
            mouseAtTop = false
            scrollDelta = 0
            print("🖱️ Mouse left top area")
        }
    }
    
    private func handleScrollEvent(_ event: NSEvent) {
        // Get scroll delta (positive = scroll UP)
        let delta = event.scrollingDeltaY
        
        // Log all scroll events for debugging
        if abs(delta) > 0.5 {
            print("📜 Scroll: \(String(format: "%.1f", delta)) | At top: \(mouseAtTop)")
        }
        
        // Only accumulate when mouse is at top
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
                // Don't reset mouseAtTop - allow repeated activations
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
        
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        
        print("⏹️ Mouse tracker stopped")
    }
    
    deinit {
        stopTracking()
    }
}
