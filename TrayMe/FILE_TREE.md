# TrayMe - Complete File Tree

```
TrayMe/
│
├── 📱 Application Core
│   └── TrayMeApp.swift                     [Main app entry, AppDelegate, status bar]
│
├── 📊 Data Models
│   ├── Models/
│   │   ├── ClipboardItem.swift             [Clipboard entry with type detection]
│   │   ├── FileItem.swift                  [File reference with metadata]
│   │   └── Note.swift                      [Note document with timestamps]
│
├── 🎮 Business Logic
│   ├── Managers/
│   │   ├── ClipboardManager.swift          [Clipboard monitoring & persistence]
│   │   ├── FilesManager.swift              [File management & drag-drop]
│   │   └── NotesManager.swift              [Notes CRUD & search]
│
├── 🎨 User Interface
│   ├── UI/
│   │   ├── MainPanel.swift                 [Custom NSPanel with animations]
│   │   ├── MainPanelView.swift             [Main SwiftUI layout & tabs]
│   │   └── Views/
│   │       ├── ClipboardView.swift         [Clipboard UI with favorites]
│   │       ├── FilesView.swift             [Files grid with drag-drop]
│   │       └── NotesView.swift             [Notes editor with sidebar]
│
├── 🔧 Utilities
│   ├── Utilities/
│   │   └── MouseTracker.swift              [Top-screen mouse detection]
│
├── ⚙️ Settings & Preferences
│   ├── Settings/
│   │   ├── AppSettings.swift               [@AppStorage wrapper for prefs]
│   │   └── SettingsView.swift              [Settings UI with tabs]
│
├── 📋 Configuration
│   ├── Info.plist                          [App metadata & permissions]
│   └── TrayMe.entitlements                 [Sandbox & security settings]
│
├── 📖 Documentation
│   ├── Readme.md                           [Main project README]
│   ├── BUILD_GUIDE.md                      [Detailed build instructions]
│   ├── QUICKSTART.md                       [Quick reference guide]
│   ├── PROJECT_STRUCTURE.md                [Architecture deep-dive]
│   ├── UI_DESIGN.md                        [UI/UX specifications]
│   ├── SUMMARY.md                          [Complete project summary]
│   └── FILE_TREE.md                        [This file]
│
├── 🛠️ Setup & Build
│   ├── setup.sh                            [Automated setup script]
│   └── .gitignore                          [Git ignore rules]
│
└── 📦 Generated (not in repo)
    ├── TrayMe.xcodeproj/                   [Created by you in Xcode]
    ├── build/                              [Build artifacts]
    └── DerivedData/                        [Xcode cache]
```

---

## File Statistics

### Source Code
| Category | Files | Lines (est) |
|----------|-------|-------------|
| Models | 3 | ~200 |
| Managers | 3 | ~700 |
| UI Views | 6 | ~1,200 |
| Utilities | 1 | ~150 |
| Settings | 2 | ~250 |
| **Total** | **15** | **~2,500** |

### Documentation
| File | Size | Purpose |
|------|------|---------|
| Readme.md | ~6 KB | Main README |
| BUILD_GUIDE.md | ~15 KB | Build instructions |
| QUICKSTART.md | ~8 KB | Quick reference |
| PROJECT_STRUCTURE.md | ~12 KB | Architecture |
| UI_DESIGN.md | ~10 KB | Design specs |
| SUMMARY.md | ~10 KB | Overview |
| FILE_TREE.md | ~4 KB | This file |
| **Total** | **~65 KB** | 7 files |

### Configuration
| File | Purpose |
|------|---------|
| Info.plist | App metadata & descriptions |
| TrayMe.entitlements | Security permissions |
| .gitignore | Git exclusions |
| setup.sh | Setup automation |

---

## Dependencies

### System Frameworks (No external dependencies!)
```swift
// Built-in macOS frameworks only
import SwiftUI          // Modern UI framework
import AppKit           // macOS windowing & events
import Foundation       // Core types & utilities
import CoreGraphics     // Event taps & geometry
import UniformTypeIdentifiers  // File type handling
```

**Zero third-party dependencies!** ✅

---

## File Purposes Quick Reference

### Core Files
```
TrayMeApp.swift
├─ @main struct TrayMeApp
├─ class AppDelegate
│  ├─ setupStatusBar()
│  ├─ setupHotkey()
│  └─ togglePanel()
└─ MainPanel integration
```

### Models (Data Structure)
```
ClipboardItem.swift  → Clipboard entry (id, content, timestamp, type)
FileItem.swift       → File reference (url, name, size, icon)
Note.swift          → Note document (title, content, dates, pinned)
```

### Managers (Business Logic)
```
ClipboardManager.swift
├─ NSPasteboard monitoring (500ms polling)
├─ History tracking (max 100 items)
├─ Favorites system
├─ Password manager filtering
└─ JSON persistence

FilesManager.swift
├─ File URL bookmarking
├─ Drag & drop handling
├─ Metadata extraction
└─ JSON persistence

NotesManager.swift
├─ CRUD operations
├─ Search & filtering
├─ Pin/unpin functionality
└─ JSON persistence
```

### UI Views (User Interface)
```
MainPanel.swift
├─ NSPanel subclass
├─ Positioning at top
├─ Slide animations
└─ Show/hide logic

MainPanelView.swift
├─ Tab navigation
├─ Visual effects blur
└─ Layout coordination

ClipboardView.swift  → List with search, favorites, actions
FilesView.swift      → Grid with drag-drop zone
NotesView.swift      → Sidebar + editor split view
```

### Utilities
```
MouseTracker.swift
├─ CGEvent tap creation
├─ Mouse position monitoring
├─ Top-edge detection (5px threshold)
└─ Activation timer (300ms delay)
```

### Settings
```
AppSettings.swift
├─ @AppStorage properties
└─ UserDefaults integration

SettingsView.swift
├─ TabView with 4 tabs
├─ General settings
├─ Module-specific settings
└─ Live updates
```

---

## Build Artifacts (Not in Git)

```
# These are created when you build:
TrayMe.xcodeproj/
├── project.pbxproj              [Xcode project file]
├── project.xcworkspace/         [Workspace settings]
└── xcuserdata/                  [User-specific settings]

build/
└── Release/
    └── TrayMe.app               [Compiled application]

DerivedData/                     [Xcode build cache]
```

---

## Data Files (Created at Runtime)

```
~/Library/Application Support/TrayMe/
├── clipboard.json               [Clipboard history]
├── files.json                   [File references]
└── notes.json                   [All notes]

~/Library/Preferences/
└── com.yourname.TrayMe.plist    [App settings]
```

---

## Quick Navigation

| Looking for... | Check this file... |
|----------------|-------------------|
| App entry point | `TrayMeApp.swift` |
| Clipboard logic | `Managers/ClipboardManager.swift` |
| File handling | `Managers/FilesManager.swift` |
| Notes system | `Managers/NotesManager.swift` |
| Main window | `UI/MainPanel.swift` |
| UI layout | `UI/MainPanelView.swift` |
| Clipboard UI | `UI/Views/ClipboardView.swift` |
| Files UI | `UI/Views/FilesView.swift` |
| Notes UI | `UI/Views/NotesView.swift` |
| Mouse tracking | `Utilities/MouseTracker.swift` |
| Settings | `Settings/SettingsView.swift` |
| Build guide | `BUILD_GUIDE.md` |
| Usage help | `QUICKSTART.md` |

---

## File Relationships

```
TrayMeApp.swift
    ↓ creates
MainPanel.swift
    ↓ hosts
MainPanelView.swift
    ↓ contains
┌────────────┬─────────────┬──────────────┐
│            │             │              │
ClipboardView   FilesView    NotesView
    ↓              ↓            ↓
ClipboardMgr   FilesMgr    NotesMgr
    ↓              ↓            ↓
ClipboardItem  FileItem     Note
```

---

## Total Project Size

| Category | Size |
|----------|------|
| Source code | ~100 KB |
| Documentation | ~65 KB |
| Configuration | ~5 KB |
| **Total** | **~170 KB** |

**Compiled app:** ~2-3 MB  
**With all data:** ~5-10 MB

---

## Next Steps

1. **To build:** See `BUILD_GUIDE.md`
2. **To use:** See `QUICKSTART.md`
3. **To understand:** See `PROJECT_STRUCTURE.md`
4. **To customize:** See `UI_DESIGN.md`

---

**All files ready! Time to build! 🚀**
