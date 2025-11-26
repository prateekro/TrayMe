# TrayMe Development Summary

## Project Overview
TrayMe is an Unclutter clone - a macOS menu bar application that provides quick access to clipboard history, file storage, and notes. The app features a panel that slides down from the top of the screen with three side-by-side sections.

## Architecture

### Core Technologies
- **Swift 5.9+** with **SwiftUI** for UI components
- **AppKit integration** via NSPanel, NSHostingView, NSViewRepresentable
- **macOS 13.0+** deployment target
- **No Accessibility permissions required** - uses global event monitors instead

### Application Structure

#### Main Components

1. **TrayMeApp.swift**
   - Entry point using `@NSApplicationDelegateAdaptor`
   - Initializes managers and panel state
   - Sets up environment objects

2. **MainPanel.swift** (NSPanel subclass)
   - Custom borderless panel positioned at top of screen
   - Dimensions: Full screen width × 40% screen height
   - Positioned at absolute top (screen.maxY)
   - Window level: .statusBar - 1
   - Activation policy: .accessory (no Dock icon, no Cmd+Tab)
   - Slide animations: 0.3s easeOut (show), 0.25s easeIn (hide)
   - **Critical override**: `canBecomeKey = true` (enables text editing)
   - **Critical override**: `canBecomeMain = false` (stays out of Cmd+Tab)

3. **MainPanelView.swift**
   - SwiftUI container with three sections
   - Header bar with section titles and settings button
   - Uses `ThreePanelSplitView` (NSViewRepresentable wrapper around NSSplitView)
   - Visual effect blur background (.hudWindow material)

4. **ThreePanelSplitView** (NSViewRepresentable)
   - Wraps NSSplitView for resizable dividers
   - Three NSHostingView containers for SwiftUI views
   - Saves/restores divider positions to UserDefaults
   - Updates background highlighting based on selected tab

### Data Managers

#### ClipboardManager
- Polls system clipboard every 0.5 seconds
- Stores clipboard history with deduplication
- Supports favorites (starred items)
- **Key Method**: `updateItemContent()` - preserves ID and timestamp when editing
- Persistence via JSON to Application Support directory
- Max history size: 100 items (configurable)
- Can ignore password manager apps

#### FilesManager
- Stores file references with metadata
- **Performance optimized** - separate caching system
- **Image thumbnails**: PNG cache (5-20KB per image), generated on-demand
- **Workspace icons**: Instant via `NSWorkspace.shared.icon(forFile:)`
- **Security-scoped bookmarks**: Separate cache for persistent file access
- **Smart duplicate detection**: Mode-aware (reference vs stored)
- **Debounced saves**: 500ms batching to reduce disk I/O
- **Background operations**: Async bookmark creation, lazy thumbnail loading
- **File storage modes**:
  - Copy mode: Duplicates to `~/Library/Application Support/TrayMe/StoredFiles/`
  - Reference mode: Links with security-scoped bookmarks
- Supports up to 100 files with file limit enforcement
- **Quick Look integration**: Native macOS preview with spacebar
- Persistence: Minimal JSON (~10KB for 100 files) + separate caches
- Supported formats: All file types (images get thumbnails, others get workspace icons)

#### NotesManager
- Manages markdown notes with rich text editing
- Auto-save with 0.5s debounce
- Saves on: text change (debounced), note switch, view disappear
- Persistence via JSON

### Cache Architecture

#### Performance Optimization Strategy
To achieve instant app launch (<0.1s) and handle 100+ files efficiently, TrayMe uses a **separate cache system** instead of embedding binary data in JSON.

#### File Storage Structure
```
~/Library/Application Support/TrayMe/
├─ files.json                    # Minimal metadata (~10KB for 100 files)
├─ clipboard.json                # Clipboard history
├─ notes.json                    # Notes data
├─ Bookmarks/                    # Security-scoped bookmarks
│  ├─ 12345678-uuid.bookmark     # Named by FileItem UUID
│  └─ ...
└─ StoredFiles/                  # Copied files (when "Copy Files" enabled)
   ├─ document.pdf
   └─ ...

~/Library/Caches/TrayMe/
└─ Thumbnails/                   # Image thumbnails (auto-cleaned by macOS)
   ├─ a1b2c3d4hash.png           # Named by SHA256 hash of source path
   └─ ...
```

#### FileItem Persistence
```swift
// Only metadata stored in JSON (fast parsing)
enum CodingKeys: String, CodingKey {
    case id, url, name, fileType, size, addedDate
    // iconData ❌ - regenerated via NSWorkspace.shared.icon()
    // bookmarkData ❌ - cached in Bookmarks/ directory
    // thumbnailData ❌ - cached in Thumbnails/ directory
}
```

#### Cache Operations
1. **Thumbnail Cache**:
   - Key: SHA256 hash of file URL → `a1b2c3d4...abc.png`
   - Format: PNG (5-20KB per image)
   - Location: `~/Library/Caches/TrayMe/Thumbnails/`
   - Cleanup: Automatic by macOS when disk space needed

2. **Bookmark Cache**:
   - Key: FileItem UUID → `uuid.bookmark`
   - Format: Binary security-scoped bookmark data (~800 bytes)
   - Location: `~/Library/Application Support/TrayMe/Bookmarks/`
   - Cleanup: Manual when file removed from app

3. **Icon Generation**:
   - No caching needed - `NSWorkspace.shared.icon()` is instant
   - macOS handles internal caching

#### Performance Impact
| Operation | Before (embedded) | After (cached) | Improvement |
|-----------|------------------|----------------|-------------|
| App Launch | 12.952s | <0.1s | **130x faster** |
| JSON Size | 2.85 GB | ~10 KB | **285,000x smaller** |
| Add 10 files | ~2s blocking | ~50ms | **40x faster** |
| Memory | ~100MB | ~30MB | **3.3x less** |

### Data Models

#### ClipboardItem
```swift
struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    let content: String
    let timestamp: Date  // Note: property name is 'timestamp', not 'date'
    var isFavorite: Bool
    let type: ClipboardType
    
    // Two initializers:
    // 1. Simple: init(content:type:isFavorite:) - generates new ID and timestamp
    // 2. Preserving: init(id:content:type:date:isFavorite:) - keeps existing metadata
}

enum ClipboardType: String, Codable {
    case text, url, code, image
}
```

#### FileItem & Note
Similar structures with UUID, timestamp, metadata

### UI Views

#### ClipboardView
**Layout**: HStack with main list + conditional 300px edit panel

**Features**:
- Search bar with live filtering
- Favorites section (horizontal scroll, 80px height)
- Clipboard history (scrollable list)
- Footer with item count and "Clear History" button
- Edit panel appears on right when item selected

**Critical Implementation Details**:
1. **Full-row interaction**: Use `.contentShape(Rectangle())` on entire row
2. **Row highlighting**: 
   - Hover: 10% opacity
   - Selected: 20% opacity
3. **Auto-copy on selection**: Clicking any row/favorite immediately copies to clipboard
4. **Clear History behavior**: Only removes non-favorite items (`items.removeAll { !$0.isFavorite }`)
5. **Edit panel state**: Local `@State` variables (selectedItem, editedContent, saveWorkItem)

**Auto-save Implementation**:
```swift
// Debounced auto-save (0.5s delay)
saveWorkItem?.cancel()
let workItem = DispatchWorkItem { [weak manager] in
    manager?.updateItemContent(item, newContent: editedContent)
}
saveWorkItem = workItem
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
```

**Edit Panel Actions**:
- **Copy Button**: Creates temporary item with edited content, copies to clipboard
- **Save Button**: Cancels pending saves, saves immediately, closes panel
- **Close Button**: Same as Save (saves before closing)
- **Favorite Toggle**: Updates favorite status

#### ClipboardDetailView (300px side panel)
- Header with title and close button
- TextEditor with onChange for debounced auto-save
- Action buttons: Copy, Save, Favorite toggle
- Mounted/unmounted based on selectedItem != nil

#### FavoriteClipCard
- 120×60 compact card design
- Star icon, truncated content (2 lines)
- Hover effect: 15% accent color opacity
- **Must bind**: selectedItem and editedContent to parent state
- **On tap**: Sets selectedItem, editedContent, and copies to clipboard

#### FilesView
- **LazyVGrid layout** for virtual scrolling (handles 100+ files smoothly)
- **Native file cards** with instant workspace icons
- **Image thumbnails**: Loaded lazily in background with PNG cache
- **Visual badges**: Green "Stored" vs Orange "Ref" indicators
- **Quick Look integration**:
  - Press Space to preview (native macOS QLPreviewPanel)
  - Arrow keys (←/→/↑/↓) to navigate between files
  - Security-scoped resource access for reference files
- **File operations**:
  - Drag & drop to add files
  - Drag out to other apps
  - Right-click context menu: Open, Reveal in Finder, Copy Image, Delete
  - Smart duplicate prevention (mode-aware)
- **Footer controls**:
  - File count with limit indicator
  - "Copy Files" toggle (stored vs reference mode)
  - File limit selector (25/50/75/100)
  - "Delete..." menu (All References, All Stored, Everything)
- **Drop validation**: Pre-check available slots before accepting files
- **Performance**: Instant rendering, background thumbnail loading

#### NotesView
- Sidebar with notes list
- Main editor area with TextEditor
- Auto-save pattern (same as clipboard editing)
- Markdown support

### Mouse Interaction System

#### Scroll Gesture to Open Panel
```swift
// In MainPanel.swift setupScrollMonitor()
NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { event in
    let mouseY = NSEvent.mouseLocation.y
    let screenHeight = NSScreen.main?.frame.height ?? 0
    
    // At top 5px of screen, scroll UP 20px total -> open
    if mouseY >= screenHeight - 5 {
        self.scrollDeltaY += event.scrollingDeltaY
        if self.scrollDeltaY >= 20 {
            self.show()
            self.scrollDeltaY = 0
        }
    }
    
    // Outside panel, scroll DOWN 5px -> close
    if !self.isMouseInside && event.scrollingDeltaY < 0 {
        self.scrollDeltaY += abs(event.scrollingDeltaY)
        if self.scrollDeltaY >= 5 {
            self.hide()
            self.scrollDeltaY = 0
        }
    }
}
```

#### Drag-and-Drop File Detection
**Challenge**: Detect file drag at screen top without Accessibility permissions

**Solution**: DragDetectorWindow
- Invisible NSWindow at screen top
- 5px tall, full screen width
- Window level: .statusBar
- Tracks leftMouseDragged events
- Triggers callbacks when drag detected at top
- MainPanel shows when drag starts, hides when drag ends outside

```swift
class DragDetectorWindow: NSWindow {
    var onDragAtTop: (() -> Void)?
    var onDragEndOutside: (() -> Void)?
    
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDragged {
            onDragAtTop?()
        }
        super.sendEvent(event)
    }
}
```

#### Click Outside to Close
- Global mouse monitor on leftMouseDown
- Checks if click is outside panel frame
- Excludes drag detector window from "outside" detection
- Calls panel.hide() when clicked outside

### Settings System

#### AppSettings (ObservableObject)
- Stored in UserDefaults via @AppStorage
- Settings:
  - Launch at login (LSUIElement in Info.plist)
  - Show in menu bar
  - Keyboard shortcut
  - Max clipboard history
  - Auto-save notes
  - Theme preference

#### SettingsView
- macOS standard settings window
- Tabs for General, Clipboard, Files, Notes
- Opens via Settings button or menu bar

## Key Challenges & Solutions

### Challenge 1: Text Editing Not Working
**Problem**: TextEditor and TextField inputs were unresponsive in NSPanel

**Root Cause**: NSPanel default `canBecomeKey = false`

**Solution**:
```swift
override var canBecomeKey: Bool { true }
override var canBecomeMain: Bool { false }  // Keep out of Cmd+Tab
```

### Challenge 2: Notes Not Saving
**Problem**: Notes content lost when switching or closing panel

**Solution**: Multi-scenario auto-save
1. Debounced save on text change (0.5s delay)
2. Immediate save on note switch (in selectNote function)
3. Immediate save on view disappear (onDisappear)
4. Cancel pending saves before new save

### Challenge 3: Clipboard Row Not Fully Clickable
**Problem**: Only text area responded to clicks, not entire row

**Solution**: Add `.contentShape(Rectangle())` modifier to make entire row interactive

### Challenge 4: File Thumbnails Not Showing
**Problem**: Generic file icons instead of image previews

**Solution**: Implement thumbnail generation
```swift
func generateThumbnail(for url: URL) -> NSImage? {
    let size = CGSize(width: 160, height: 120)
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: max(size.width, size.height)
    ]
    // Generate and return thumbnail...
}
```

### Challenge 5: Favorites Unusable After Clear History
**Problem**: Clear History removed all items including favorites from the list

**Root Cause**: `items.removeAll()` cleared everything

**Solution**: Selective removal
```swift
func clearHistory() {
    items.removeAll { !$0.isFavorite }  // Keep favorites
    saveToDisk()
}
```

### Challenge 6: Favorites Not Clickable After Clear
**Problem**: Favorite cards lost interactivity after history cleared

**Root Cause**: Favorite cards weren't properly bound to parent state

**Solution**: Pass bindings to FavoriteClipCard
```swift
FavoriteClipCard(item: item, selectedItem: $selectedItem, editedContent: $editedContent)
```

### Challenge 7: Editing Clipboard Items
**Problem**: No way to modify clipboard item content

**Solution**: Side-by-side edit panel
- 300px ClipboardDetailView appears on right
- TextEditor with debounced auto-save
- Copy button for edited content
- Save/Close buttons to finish editing

### Challenge 8: Copy Button Crashes in Edit Panel
**Problem**: Wrong initializer used - `date` parameter doesn't exist

**Root Cause**: ClipboardItem property is `timestamp`, not `date`

**Solution**: Use simple initializer
```swift
let tempItem = ClipboardItem(content: editedContent, type: item.type)
manager.copyToClipboard(tempItem)
```

### Challenge 9: Edited Content Blanks Clipboard
**Problem**: Auto-copy on selection interfered with clipboard manager polling

**Initial Wrong Solution**: Removed auto-copy (breaking critical feature)

**Correct Solution**: Keep auto-copy (it's essential), fix Copy button initializer instead

### Challenge 10: Window Positioning and Chrome
**Problem**: Panel had standard window buttons and wrong position

**Solution**: Borderless at screen top
```swift
styleMask = [.borderless, .nonactivatingPanel]
level = .statusBar - 1
setFrame(NSRect(x: 0, y: screen.maxY - height, width: screen.width, height: height))
```

### Challenge 11: Slide Animation From Wrong Position
**Problem**: Panel slid from screen.maxY (bottom of coordinate space)

**Understanding**: macOS coordinate system has origin at bottom-left
- screen.maxY = top of screen
- screen.minY = bottom of screen

**Solution**: Slide from/to screen.maxY (top)
```swift
// Hide: slide UP to screen.maxY (off top)
// Show: slide DOWN from screen.maxY to (screen.maxY - height)
```

### Challenge 12: Replacing Files Tab with Edit Panel
**Attempted**: Dynamic view switching in ThreePanelSplitView based on state

**Problem**: NSViewRepresentable doesn't reactively update content properly

**Solution**: Reverted to side-by-side edit panel (simpler, more stable)
- Edit panel appears within ClipboardView as 300px side panel
- All 3 tabs always visible and functional
- Better UX - user can see Files and Notes while editing

## Critical Implementation Notes

### 1. Always Use .contentShape(Rectangle())
For any interactive row/card that should respond to clicks anywhere:
```swift
VStack { ... }
    .contentShape(Rectangle())
    .onTapGesture { ... }
```

### 2. Auto-save Pattern
```swift
@State private var saveWorkItem: DispatchWorkItem?

// On change:
saveWorkItem?.cancel()
let workItem = DispatchWorkItem { [weak manager] in
    manager?.saveMethod()
}
saveWorkItem = workItem
DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)

// On explicit save:
saveWorkItem?.cancel()
manager.saveMethod()
```

### 3. Preserving Metadata When Editing
Use custom initializer to keep ID and timestamp:
```swift
init(id: UUID, content: String, type: ClipboardType, date: Date, isFavorite: Bool) {
    self.id = id
    self.content = content
    self.timestamp = date  // Note: parameter 'date', property 'timestamp'
    self.type = type
    self.isFavorite = isFavorite
}
```

### 4. NSSplitView Integration
```swift
struct ThreePanelSplitView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSSplitView {
        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        
        // Wrap SwiftUI views in NSHostingView
        let view1 = NSHostingView(rootView: swiftUIView1)
        splitView.addArrangedSubview(view1)
        // ...
        
        return splitView
    }
}
```

### 5. Global Event Monitors
Don't require Accessibility permissions:
```swift
NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { event in
    // Handle event
}
```

### 6. Panel Show/Hide with Animation
```swift
func show() {
    let screen = NSScreen.main!.frame
    let startY = screen.maxY  // Off top
    let endY = screen.maxY - frame.height  // Visible position
    
    setFrameOrigin(NSPoint(x: 0, y: startY))
    orderFrontRegardless()
    
    NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.3
        context.timingFunction = CAMediaTimingFunction(name: .easeOut)
        animator().setFrameOrigin(NSPoint(x: 0, y: endY))
    }
}
```

### 7. Debounced Saves Must Cancel Previous
Always cancel before creating new work item:
```swift
saveWorkItem?.cancel()  // Critical!
let workItem = DispatchWorkItem { ... }
saveWorkItem = workItem
```

### 8. UserDefaults for Persistence
```swift
private var saveURL: URL {
    let appSupport = FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
    ).first!
    let appFolder = appSupport.appendingPathComponent("TrayMe")
    try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
    return appFolder.appendingPathComponent("clipboard.json")
}
```

## File Structure
```
TrayMe/
├── TrayMeApp.swift                 # App entry point
├── Info.plist                      # LSUIElement = true for menu bar app
├── TrayMe.entitlements            # Sandboxing (if needed)
├── Managers/
│   ├── ClipboardManager.swift     # Clipboard polling & history
│   ├── FilesManager.swift         # File storage & thumbnails
│   └── NotesManager.swift         # Notes with auto-save
├── Models/
│   ├── ClipboardItem.swift        # Data model with dual initializers
│   ├── FileItem.swift
│   └── Note.swift
├── UI/
│   ├── MainPanel.swift            # Custom NSPanel with animations
│   ├── MainPanelView.swift        # SwiftUI container + PanelState
│   └── Views/
│       ├── ClipboardView.swift    # List + 300px edit panel
│       ├── FilesView.swift        # Grid with thumbnails
│       └── NotesView.swift        # List + editor
├── Settings/
│   ├── AppSettings.swift          # UserDefaults wrapper
│   └── SettingsView.swift         # Settings window
├── Utilities/
│   └── MouseTracker.swift         # Global event monitors
└── Assets.xcassets/
    └── AppIcon.appiconset/
```

## Testing Checklist

### Clipboard Functionality
- [ ] Items appear in history when copied
- [ ] Clicking item copies to clipboard
- [ ] Favorites toggle works
- [ ] Search filters items
- [ ] Clear History keeps favorites
- [ ] Edit panel opens on click
- [ ] Editing auto-saves (wait 0.5s)
- [ ] Copy button in edit panel works
- [ ] Save/Close saves and closes panel
- [ ] Favorites cards are clickable

### Files Functionality
- [ ] Drag file to top of screen shows panel
- [ ] File appears in grid after drop
- [ ] Image thumbnails generate correctly
- [ ] Open/Reveal in Finder works
- [ ] Delete removes file

### Notes Functionality
- [ ] Create new note
- [ ] Edit note content
- [ ] Auto-save works on typing
- [ ] Switching notes saves previous
- [ ] Closing panel saves current note
- [ ] Delete note works

### Panel Behavior
- [ ] Scroll up at top edge opens panel
- [ ] Scroll down outside closes panel
- [ ] Click outside closes panel
- [ ] Drag file at top opens panel
- [ ] Animations smooth (0.3s show, 0.25s hide)
- [ ] Panel positioned at absolute top
- [ ] Text editing works in all fields
- [ ] Panel stays out of Cmd+Tab

### Dividers & Layout
- [ ] Three panels visible side by side
- [ ] Dividers are draggable
- [ ] Positions saved on resize
- [ ] Positions restored on relaunch

## Known Limitations

1. **Clipboard Polling**: 0.5s delay means very rapid clipboard changes might be missed
2. **File Storage**: Files are referenced, not copied (broken if original moved/deleted)
3. **No iCloud Sync**: All data stored locally
4. **Menu Bar Icon**: Uses system image (no custom design)
5. **Accessibility**: Cannot detect drags from all apps without permissions

## Future Enhancements

1. Pasteboard type detection (images, files, rich text)
2. Clipboard history search with fuzzy matching
3. Tags/categories for files and notes
4. iCloud sync for notes
5. Custom keyboard shortcuts
6. Multi-monitor support
7. Clipboard snippet preview
8. File copy option (not just reference)
9. Export clipboard history
10. Themes and customization

## Comprehensive Prompt for Recreation

```
Create a macOS menu bar application called TrayMe (an Unclutter clone) with the following specifications:

ARCHITECTURE:
- Swift 5.9+, SwiftUI + AppKit hybrid, macOS 13.0+
- NSPanel-based borderless window (full width, 40% height, positioned at absolute top)
- Window level: .statusBar - 1, activation policy: .accessory
- Override canBecomeKey=true, canBecomeMain=false
- Three side-by-side resizable panels using NSSplitView wrapped in NSViewRepresentable
- Slide animations: 0.3s easeOut down from top (show), 0.25s easeIn up to top (hide)

PANELS:
1. Clipboard: History list with search, favorites (horizontal scroll), editable items (300px side panel with debounced auto-save)
2. Files: Grid with drag-and-drop, image thumbnails (160x120), open/reveal/delete actions
3. Notes: List + markdown editor with auto-save on change (0.5s debounce), switch, and disappear

INTERACTIONS:
- Scroll up 20px at top 5px of screen -> opens panel
- Scroll down 5px outside panel -> closes panel
- Drag file to screen top -> opens panel (use 5px invisible DragDetectorWindow)
- Click outside -> closes panel
- Click clipboard row/favorite -> copies to clipboard + opens 300px edit panel

KEY IMPLEMENTATIONS:
- ClipboardItem with dual initializers (simple + metadata-preserving)
- Auto-save pattern: DispatchWorkItem with 0.5s debounce, cancel before new save
- Full-row clickable: .contentShape(Rectangle())
- Clear history keeps favorites: items.removeAll { !$0.isFavorite }
- Thumbnail generation for images: jpg/png/gif/heic/webp support
- Persistence: JSON to Application Support directory
- Global event monitors (no Accessibility permissions needed)

CRITICAL DETAILS:
- Property is 'timestamp', not 'date' in ClipboardItem
- macOS coordinates: origin bottom-left, screen.maxY = top
- Always cancel saveWorkItem before creating new one
- FavoriteClipCard needs bindings to parent selectedItem and editedContent
- Copy button in edit panel uses simple ClipboardItem initializer
- updateItemContent() preserves ID and timestamp when editing
```

## Conclusion

TrayMe successfully replicates core Unclutter functionality using modern SwiftUI with strategic AppKit integration. The key to success was understanding NSPanel behavior, implementing proper auto-save patterns, and solving mouse interaction challenges without requiring Accessibility permissions. The side-by-side edit panel proved more stable than dynamic view replacement approaches.
