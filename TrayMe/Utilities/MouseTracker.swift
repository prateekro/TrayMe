//
//  MouseTracker.swift
//  TrayMe
//

import AppKit
import CoreGraphics

class MouseTracker {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let activationCallback: () -> Void
    
    private var mouseAtTop = false
    private var scrollDelta: CGFloat = 0
    private let scrollThreshold: CGFloat = 50 // Amount of scroll needed to trigger
    
    init(activationCallback: @escaping () -> Void) {
        self.activationCallback = activationCallback
        startTracking()
    }
    
    func startTracking() {
        // Create event tap for mouse moved and scroll events
        let eventMask = (1 << CGEventType.mouseMoved.rawValue) | 
                       (1 << CGEventType.scrollWheel.rawValue)
        
        guard let eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let tracker = Unmanaged<MouseTracker>.fromOpaque(refcon!).takeUnretainedValue()
                
                if type == .mouseMoved {
                    tracker.handleMouseEvent(event: event)
                } else if type == .scrollWheel {
                    tracker.handleScrollEvent(event: event)
                }
                
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("⚠️ Failed to create event tap - accessibility permissions may be needed")
            return
        }
        
        self.eventTap = eventTap
        
        // Create run loop source
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        
        // Add to run loop
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        
        // Enable the event tap
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        print("✅ Mouse tracker started")
    }
    
    private func handleMouseEvent(event: CGEvent) {
        let location = event.location
        
        // Get main screen dimensions
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        
        // Check if mouse is at the very top of the screen (within 10 pixels)
        let isAtTop = location.y >= screenFrame.height - 10
        
        if isAtTop && !mouseAtTop {
            // Mouse just entered top area
            mouseAtTop = true
            scrollDelta = 0 // Reset scroll accumulator
            print("🖱️ Mouse at top edge")
        } else if !isAtTop && mouseAtTop {
            // Mouse left top area
            mouseAtTop = false
            scrollDelta = 0
        }
    }
    
    private func handleScrollEvent(event: CGEvent) {
        // Only track scroll when mouse is at top
        guard mouseAtTop else {
            scrollDelta = 0
            return
        }
        
        // Get scroll delta (negative = scroll down)
        let delta = CGFloat(event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
        
        // Accumulate downward scroll
        if delta < 0 {
            scrollDelta += abs(delta)
            print("📜 Scroll delta: \(scrollDelta)")
            
            // Trigger when threshold reached
            if scrollDelta >= scrollThreshold {
                print("🎯 Scroll threshold reached - opening panel")
                scrollDelta = 0
                mouseAtTop = false // Reset to prevent repeated triggers
                activationCallback()
            }
        } else {
            // Reset on upward scroll
            scrollDelta = 0
        }
    }
    
    func stopTracking() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        
        print("⏹️ Mouse tracker stopped")
    }
    
    deinit {
        stopTracking()
    }
}
