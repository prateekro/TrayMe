//
//  DragDetectorWindow.swift
//  TrayMe
//
//  Invisible window at top of screen to detect file drags
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

class DragDetectorWindow: NSWindow {
    private let dragStartCallback: () -> Void
    private let dragEndCallback: () -> Void
    private let dragActivateCallback: () -> Void
    
    init(dragStartCallback: @escaping () -> Void,
         dragEndCallback: @escaping () -> Void,
         dragActivateCallback: @escaping () -> Void) {
        self.dragStartCallback = dragStartCallback
        self.dragEndCallback = dragEndCallback
        self.dragActivateCallback = dragActivateCallback
        
        guard let screen = NSScreen.main else {
            fatalError("No main screen found")
        }
        
        let screenFrame = screen.frame
        
        // Create thin strip at top of screen
        let windowRect = NSRect(
            x: 0,
            y: screenFrame.maxY - 5, // Top 5 pixels
            width: screenFrame.width,
            height: 5
        )
        
        super.init(
            contentRect: windowRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // Window configuration
        self.level = .statusBar // Same level as menu bar
        self.backgroundColor = .clear
        self.isOpaque = false
        self.ignoresMouseEvents = false
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        self.hasShadow = false
        self.acceptsMouseMovedEvents = true
        
        // Register for drag types
        self.registerForDraggedTypes([.fileURL])
        
        // Create content view with drag support
        let contentView = DragDetectorView(
            dragStartCallback: dragStartCallback,
            dragEndCallback: dragEndCallback,
            dragActivateCallback: dragActivateCallback
        )
        let hostingView = NSHostingView(rootView: contentView)
        self.contentView = hostingView
        
        // Show the window
        self.orderFront(nil)
        
        print("🎯 Drag detector window created at top of screen")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Allow drags to pass through when not over our window
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

struct DragDetectorView: View {
    let dragStartCallback: () -> Void
    let dragEndCallback: () -> Void
    let dragActivateCallback: () -> Void
    @State private var isDragging = false
    @State private var hasTriggered = false
    
    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
                // Don't consume the drop - let it pass to FilesView
                return false
            }
            .onChange(of: isDragging) { oldValue, newValue in
                print("� Drag targeting changed: \(newValue)")
                
                if newValue {
                    // Drag entered
                    dragStartCallback()
                    
                    // Trigger panel opening once
                    if !hasTriggered {
                        hasTriggered = true
                        print("🗂️ File drag detected at top - opening Files tab")
                        // Defer to avoid reentrant message
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            dragActivateCallback()
                        }
                    }
                } else {
                    // Drag exited
                    dragEndCallback()
                    hasTriggered = false
                }
            }
    }
}
