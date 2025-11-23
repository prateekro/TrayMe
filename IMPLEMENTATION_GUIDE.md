# TrayMe - Unclutter Clone Implementation Guide

## Project Overview

TrayMe is a macOS menu bar productivity app inspired by Unclutter. It provides three core features:
1. **Clipboard Manager** - Track and manage clipboard history
2. **Files Hub** - Quick access to frequently used files
3. **Quick Notes** - Fast note-taking without switching apps

## Key Features

### Mouse Gesture Activation
- **Scroll UP** when mouse is at top 5px of screen → Panel slides down from top
- **Scroll DOWN** anywhere outside panel → Panel hides
- **Click** anywhere outside panel → Panel hides
- **Hotkey** Cmd+Ctrl+Shift+U → Toggle panel
- **Menu bar icon** → Toggle panel

### No Accessibility Permissions Required
The app uses standard AppKit APIs with global event monitors for mouse tracking and scroll detection.

## Architecture

### Main Components

1. **TrayMeApp.swift** - App entry point with AppDelegate
   - Sets activation policy to `.accessory` (menu bar app)
   - Creates status bar item
   - Initializes managers (Clipboard, Files, Notes, Settings)
   - Sets up global hotkey (Cmd+Ctrl+Shift+U, keyCode 32)
   - Initializes MouseTracker with callback to show panel

2. **MainPanel.swift** - Custom NSPanel with animations
   - Positioned at top-center of screen
   - Slide-down animation (0.3s easeOut) when showing
   - Slide-up animation (0.25s easeIn) when hiding
   - Click-outside-to-close monitor
   - Scroll-down-to-close monitor (local + global)
   - Hosts SwiftUI content view

3. **MouseTracker.swift** - Detects mouse at top + scroll gesture
   - Global mouse movement monitor checks if Y >= screenHeight - 5px
   - When mouse at top: enables scroll tracking
   - Accumulates upward scroll (positive delta)
   - Triggers callback at 20px threshold
   - Resets on downward scroll or mouse leaving top area

4. **MainPanelView.swift** - SwiftUI main interface
   - TabView with 3 tabs: Clipboard, Files, Notes
   - Settings button (temporarily switches to `.regular` activation policy)
   - Environment objects for all managers

### Managers

1. **ClipboardManager** - ObservableObject
   - Monitors pasteboard with timer
   - Stores clipboard items with timestamp
   - Detects text, images, URLs, files

2. **FilesManager** - ObservableObject
   - Manages pinned files list
   - Add/remove files functionality
   - Persistent storage via UserDefaults

3. **NotesManager** - ObservableObject
   - CRUD operations for notes
   - Auto-save to UserDefaults
   - Note model with id, content, timestamp

4. **AppSettings** - ObservableObject
   - Published properties for all settings
   - Auto-save via `didSet` observers
   - `isLoading` flag to prevent double-save during init

## Critical Implementation Details

### 1. Mouse Tracking (No Blocking Window)

```swift
// MouseTracker.swift
private func checkMousePosition() {
    let mouseLocation = NSEvent.mouseLocation
    let screenFrame = NSScreen.main?.frame
    
    // Y=0 is at bottom, top is screenFrame.maxY
    let isAtTop = mouseLocation.y >= screenFrame.maxY - 5
    
    if isAtTop && !mouseAtTop {
        mouseAtTop = true
        scrollDelta = 0
    } else if !isAtTop && mouseAtTop {
        mouseAtTop = false
        scrollDelta = 0
    }
}
```

### 2. Scroll Event Handling

```swift
// MouseTracker.swift - OPEN panel
private func handleScrollEvent(_ event: NSEvent) {
    let delta = event.scrollingDeltaY  // Positive = UP
    
    guard mouseAtTop else {
        scrollDelta = 0
        return
    }
    
    if delta > 0 {
        scrollDelta += abs(delta)
        if scrollDelta >= 20 {
            activationCallback()  // Show panel
            scrollDelta = 0
            // DON'T reset mouseAtTop - allow repeated opens
        }
    } else if delta < 0 {
        scrollDelta = max(0, scrollDelta - abs(delta))
    }
}

// MainPanel.swift - CLOSE panel
scrollMonitorGlobal = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { event in
    guard self.isVisible else { return }
    
    let mouseLocation = NSEvent.mouseLocation
    
    if !self.frame.contains(mouseLocation) {
        if event.scrollingDeltaY < -5 {  // Scroll DOWN
            self.hide()
        }
    }
}
```

### 3. Panel Animations

```swift
// MainPanel.swift
func show() {
    guard !self.isVisible else { return }
    
    positionAtTopOfScreen()
    
    // Start off-screen above
    var startFrame = self.frame
    startFrame.origin.y = NSScreen.main!.visibleFrame.maxY
    self.setFrame(startFrame, display: false)
    
    self.makeKeyAndOrderFront(nil)
    
    // Slide down
    NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.3
        context.timingFunction = CAMediaTimingFunction(name: .easeOut)
        self.animator().setFrame(targetFrame, display: true)
    }
}

func hide() {
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
```

### 4. Auto Layout (Prevent Layout Recursion)

```swift
// MainPanel.swift
private func setupContent() {
    let hostingView = NSHostingView(rootView: contentView)
    hostingView.translatesAutoresizingMaskIntoConstraints = false
    
    self.contentView?.addSubview(hostingView)
    
    NSLayoutConstraint.activate([
        hostingView.topAnchor.constraint(equalTo: contentView!.topAnchor),
        hostingView.bottomAnchor.constraint(equalTo: contentView!.bottomAnchor),
        hostingView.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor),
        hostingView.trailingAnchor.constraint(equalTo: contentView!.trailingAnchor)
    ])
}
```

### 5. Settings Auto-Save

```swift
// AppSettings.swift
@Published var someOption: Bool = false {
    didSet {
        if !isLoading {
            save()
        }
    }
}

private var isLoading = false

init() {
    isLoading = true
    // Load from UserDefaults
    someOption = UserDefaults.standard.bool(forKey: "someOption")
    isLoading = false
}
```

### 6. Static Formatters (Performance)

```swift
// NotesView.swift
private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()

private let relativeFormatter = RelativeDateTimeFormatter()
```

### 7. Settings Window Activation

```swift
// MainPanelView.swift
Button("Settings") {
    if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
        // Temporarily show in dock
        NSApp.setActivationPolicy(.regular)
        
        if let settingsURL = URL(string: "trayme://settings") {
            NSWorkspace.shared.open(settingsURL)
        }
        
        // Hide dock icon after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
```

## Event Monitors Summary

### MouseTracker
- **Global mouse move** - Track mouse position at screen top
- **Local scroll wheel** - Detect scroll UP when mouse at top
- **Global scroll wheel** - Detect scroll UP when mouse at top (background)

### MainPanel
- **Global left/right mouse down** - Click outside to close
- **Local scroll wheel** - Scroll down outside to close (app focused)
- **Global scroll wheel** - Scroll down outside to close (app not focused)

## Build Issues Fixed

1. **Hotkey keyCode** - Changed from 17 (T) to 32 (U)
2. **Memory leak** - Changed `passRetained` to `passUnretained` in CGEvent callback
3. **Layout recursion** - Used Auto Layout constraints, deferred content setup
4. **onChange syntax** - Updated to zero-parameter closures with async dispatch
5. **Combine imports** - Removed "internal" keyword from all import statements
6. **AppDelegate cast** - Changed `guard` to `if let` for safety
7. **AutoresizingMask** - Simplified to `[.width, .height]`

## File Structure

```
TrayMe/
├── TrayMeApp.swift                  # App entry + AppDelegate
├── Info.plist
├── TrayMe.entitlements
├── Managers/
│   ├── ClipboardManager.swift       # Clipboard monitoring
│   ├── FilesManager.swift           # File pinning
│   └── NotesManager.swift           # Notes CRUD
├── Models/
│   ├── ClipboardItem.swift          # Clipboard data model
│   ├── FileItem.swift               # File data model
│   └── Note.swift                   # Note data model
├── Settings/
│   ├── AppSettings.swift            # Settings with auto-save
│   └── SettingsView.swift           # Settings UI
├── UI/
│   ├── MainPanel.swift              # Custom NSPanel
│   ├── MainPanelView.swift          # SwiftUI main view
│   └── Views/
│       ├── ClipboardView.swift      # Clipboard tab
│       ├── FilesView.swift          # Files tab
│       └── NotesView.swift          # Notes tab
└── Utilities/
    └── MouseTracker.swift           # Mouse gesture detection
```

## Key Configuration Values

```swift
// MouseTracker
topEdgeThreshold: 5px       // Distance from top to activate
scrollThreshold: 20px       // Scroll distance to trigger

// MainPanel
width: 900px
height: 400px
level: .floating
showAnimation: 0.3s easeOut
hideAnimation: 0.25s easeIn

// Hotkey
keyCode: 32 (U)
modifiers: Cmd+Ctrl+Shift

// Scroll to close threshold
scrollDownThreshold: -5px   // Negative = scroll down
```

## Testing Checklist

- [ ] Mouse to top 5px → logs "Mouse at TOP of screen"
- [ ] Scroll UP at top → accumulates delta, opens panel at 20px
- [ ] Panel slides down smoothly (0.3s)
- [ ] Scroll DOWN anywhere outside → panel closes
- [ ] Click anywhere outside → panel closes
- [ ] Panel slides up smoothly (0.25s)
- [ ] Can open/close multiple times without moving mouse
- [ ] Hotkey Cmd+Ctrl+Shift+U toggles panel
- [ ] Menu bar icon toggles panel
- [ ] Menu bar remains fully clickable
- [ ] Settings button opens settings window
- [ ] All tabs work: Clipboard, Files, Notes
- [ ] App runs without Accessibility permissions

## Common Issues & Solutions

### Mouse tracking doesn't work
- Check console for "Mouse at TOP of screen" when moving to top
- Verify screen frame calculations (Y=0 at bottom)
- Ensure global monitors are set up

### Scroll doesn't close panel
- Verify both local AND global scroll monitors are active
- Check `self.isVisible` guard clause
- Ensure mouse position check works (`!frame.contains(mouseLocation)`)

### Menu bar blocked
- Remove any invisible windows with `ignoresMouseEvents = false`
- Use pure event monitoring instead of tracking windows

### Panel won't open second time
- Don't reset `mouseAtTop = false` after activation
- Only reset `scrollDelta = 0`

### Layout recursion warning
- Use Auto Layout constraints
- Set `translatesAutoresizingMaskIntoConstraints = false`
- Defer content setup with `DispatchQueue.main.async`

## Performance Optimizations

1. **Static formatters** - Create once, reuse everywhere
2. **Debounced saves** - Use `isLoading` flag in Settings
3. **Async UI updates** - Wrap state changes in `DispatchQueue.main.async`
4. **Lazy initialization** - Only create views when needed
5. **Event monitor efficiency** - Return events immediately in local monitors

## Future Enhancements

- [ ] Multi-display support
- [ ] Customizable hotkey
- [ ] Adjustable scroll thresholds in settings
- [ ] Clipboard search/filter
- [ ] Files quick preview
- [ ] Rich text notes support
- [ ] Sync across devices
- [ ] Themes/appearance customization
