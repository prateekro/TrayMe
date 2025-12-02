# TrayMe - Unclutter Clone

> A cross-platform productivity app with native implementations for **macOS** and **Windows**  
> **Status:** ✅ Complete & Ready to Build

## 📱 Platform Support

| Platform | Technology | Status |
|----------|------------|--------|
| **macOS** | Swift & SwiftUI | ✅ Complete |
| **Windows** | C# & WPF | ✅ Complete |

## 🎯 What is TrayMe?

TrayMe is a **3-in-1 productivity tool** that slides down from the top of your screen, giving you instant access to:

1. **📋 Clipboard Manager** - Never lose what you copied
2. **📁 Files Hub** - Temporary file storage & quick access  
3. **📝 Quick Notes** - Instant notepad without opening apps

Built with native technologies for maximum performance and minimal resource usage on each platform.

---

## ✨ Features

### Clipboard Manager
- ✅ Automatic clipboard history tracking
- ✅ Search through past clips
- ✅ Favorites system for frequently used items
- ✅ Smart type detection (text, URLs, code)
- ✅ Password manager filtering for security

### Files Hub (Drop Zone)
- ✅ Drag & drop files from Desktop/Finder
- ✅ Drag files out to other apps
- ✅ **Quick Look preview** with spacebar (native macOS preview)
- ✅ **Arrow key navigation** in Quick Look
- ✅ **Native Finder-style thumbnails** for images
- ✅ **Instant workspace icons** for all file types
- ✅ **Copy files** to storage or **reference** originals
- ✅ Visual badges (Green "Stored" vs Orange "Ref")
- ✅ Quick open or reveal in Finder
- ✅ Copy image to clipboard
- ✅ **Security-scoped bookmarks** for persistent access (survives app restart)
- ✅ **File limit enforcement** (up to 100 files)
- ✅ **Smart duplicate detection** (allows same file as reference & copy)
- ✅ Temporary storage without Desktop clutter
- ✅ **Blazing fast performance** - optimized for 100+ files

### Quick Notes
- ✅ Instant note creation
- ✅ Auto-save functionality
- ✅ Full-text search
- ✅ Pin important notes
- ✅ Clean, distraction-free editor

### System Integration
- ✅ Top-screen mouse activation (macOS)
- ✅ Global hotkey (Cmd+Shift+U on macOS, Ctrl+Shift+U on Windows)
- ✅ Menu bar / System tray icon
- ✅ Works across all Spaces (macOS)
- ✅ Full-screen app compatible

---

## 🚀 Quick Start

### macOS

#### Prerequisites
- macOS 12.0 (Monterey) or later
- Xcode 14.0+
- Apple Developer account (free tier works)

#### Setup (2 minutes)

```bash
cd TrayMe
./setup.sh
```

Then follow the printed instructions to create your Xcode project.

**OR** see **[BUILD_GUIDE.md](BUILD_GUIDE.md)** for detailed step-by-step instructions.

### Windows

#### Prerequisites
- Windows 10/11
- .NET 8.0 SDK or later
- Visual Studio 2022 (recommended)

#### Build and Run

```bash
cd TrayMe.Windows
dotnet restore
dotnet build
dotnet run
```

Or open `TrayMe.Windows/TrayMe.Windows.csproj` in Visual Studio and press F5.

---

## 📖 Documentation

| Document | Description |
|----------|-------------|
| **[TrayMe.Windows/README.md](TrayMe.Windows/README.md)** | Windows-specific documentation |
| **[BUILD_GUIDE.md](BUILD_GUIDE.md)** | macOS build & setup instructions |
| **[PERFORMANCE.md](PERFORMANCE.md)** | Performance optimizations & benchmarks |
| **[DEVELOPMENT_SUMMARY.md](DEVELOPMENT_SUMMARY.md)** | Architecture & implementation details |
| **[QUICKSTART.md](QUICKSTART.md)** | Quick reference for common tasks |
| **[PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)** | Code organization & file structure |
| **[UI_DESIGN.md](UI_DESIGN.md)** | UI/UX specifications & design |

---

## 🏗️ Architecture

### macOS
**Language:** Swift 5.9+  
**UI Framework:** SwiftUI (with AppKit bridge)  
**Platform:** macOS 12.0+

### Windows
**Language:** C# 12  
**UI Framework:** WPF  
**Platform:** Windows 10/11, .NET 8.0+

### Why Native Technologies?
✅ **Fast execution** - Native compilation  
✅ **Minimal resources** - ~20MB memory, <1% CPU  
✅ **Fresh UI** - Modern platform-native design
✅ **System integration** - Direct access to macOS APIs

### Project Structure
```
TrayMe/
├── TrayMeApp.swift          # Main app & delegate
├── Models/                  # Data models (3 files)
├── Managers/                # Business logic (3 files)
├── UI/                      # SwiftUI views (6 files)
├── Utilities/               # Mouse tracking (1 file)
├── Settings/                # Preferences (2 files)
├── Info.plist              # App configuration
└── TrayMe.entitlements     # Permissions
```

---

## 🎮 Usage

### Activation Methods
| Method | Action |
|--------|--------|
| **Mouse** | Move to top of screen |
| **Hotkey** | Press `Cmd+Shift+U` |
| **Menu Bar** | Click tray icon |

### Files Tab Shortcuts
| Shortcut | Action |
|----------|--------|
| **Space** | Quick Look preview (toggle) |
| **←/→ Arrows** | Navigate files in Quick Look |
| **↑/↓ Arrows** | Navigate files in Quick Look |
| **Drag & Drop** | Add files (auto-detects at top) |
| **Right Click** | Context menu options |

### File Storage Options
- **Copy Files:** Duplicates files to app storage (survives original deletion)
- **Reference Files:** Links to original location (smaller storage, requires original)
- Toggle via "Copy Files" checkbox in Files tab footer
- Visual badges: Green "Stored" or Orange "Ref"

### First Launch
1. Grant **Accessibility** permissions (for mouse tracking)
2. Click menu bar icon or use hotkey
3. Panel slides down - you're ready!

---

## ⚙️ Settings

Access via menu bar → Preferences or `Cmd+,`

- **General:** Activation methods, hotkey, panel size
- **Clipboard:** History limit, password filtering
- **Files:** Maximum stored files
- **Notes:** iCloud sync (coming soon)

---

## 🔒 Privacy & Security

- ✅ All data stored **locally** on your Mac
- ✅ **No network requests** or telemetry
- ✅ **Password manager filtering** built-in
- ✅ **App Sandbox** enabled
- ✅ Only accesses files you explicitly drag in

**Data Location:**  
`~/Library/Application Support/TrayMe/`

---

## 🎯 Feature Parity with Unclutter

| Feature | Status |
|---------|--------|
| Clipboard Manager | ✅ Complete |
| Files Hub | ✅ Complete |
| **Quick Look Preview** | ✅ **Complete** |
| **File Storage Options** | ✅ **Complete** |
| Quick Notes | ✅ Complete |
| Top-screen activation | ✅ Complete |
| Hotkey support | ✅ Complete |
| Multi-Space support | ✅ Complete |
| Drag & drop | ✅ Complete |
| Search | ✅ Complete |
| Favorites | ✅ Complete |
| Settings | ✅ Complete |
| iCloud Sync | ⏳ Future |
| Rich Text Notes | ⏳ Future |

**12/12 core features complete!**

---

## 🛠️ Development

### Building
```bash
# Create Xcode project (see BUILD_GUIDE.md)
open TrayMe.xcodeproj

# Or from command line
xcodebuild -scheme TrayMe -configuration Debug
```

### Testing
1. Build & Run in Xcode (`Cmd+R`)
2. Grant accessibility permissions
3. Test all three panels
4. Verify mouse activation
5. Check hotkey works

---

## 📊 Performance

**Optimized for speed and efficiency:**

- **Memory:** ~20MB idle, ~30MB active (minimal footprint)
- **CPU:** <1% idle, 2-3% active (battery-friendly)
- **App Launch:** <0.1s instant startup (even with 100 files!)
- **File Operations:**
  - Add 10 files: ~50ms
  - Quick Look: Instant preview
  - Thumbnail generation: Background, non-blocking
  - Search: Real-time filtering
- **Storage:**
  - App binary: ~5MB
  - JSON metadata: ~10KB for 100 files
  - Thumbnails: Cached separately (~5-20KB per image)
  - Bookmarks: Cached separately (~800 bytes per reference file)

### Performance Optimizations Applied:
✅ **Separate caching system** - Thumbnails & bookmarks stored outside JSON  
✅ **Debounced disk writes** - Batches saves to reduce I/O  
✅ **Background operations** - File loading, bookmark creation off main thread  
✅ **Lazy rendering** - LazyVGrid only renders visible items  
✅ **Native APIs** - NSWorkspace for instant file icons  
✅ **Minimal JSON** - Only essential metadata persisted  

**Result:** App handles 100 files with zero lag!

---

## 🗺️ Roadmap

### Implemented ✅
- [x] Clipboard management with history
- [x] Files hub with drag & drop
- [x] **Quick Look integration** with spacebar & arrow navigation
- [x] **File storage modes** (copy vs reference with visual badges)
- [x] **Image thumbnails** with separate disk cache
- [x] **Security-scoped bookmarks** for persistent file access
- [x] **Smart duplicate detection** (mode-aware)
- [x] **Performance optimizations** (instant app launch, lazy loading)
- [x] **File limit management** (up to 100 files)
- [x] Quick notes with auto-save
- [x] Mouse activation with top-screen detection
- [x] Global hotkey support (Cmd+Shift+U)
- [x] Settings panel with customization
- [x] Full-text search across all tabs

### Future Enhancements ⏳
- [ ] iCloud sync for notes
- [ ] Universal Clipboard integration
- [ ] Rich text support
- [ ] Code syntax highlighting
- [ ] Custom themes
- [ ] Export/import data

---

## 📝 License

Personal/Educational project - Built as an Unclutter clone for learning purposes.

---

## 🙏 Credits

Inspired by [Unclutter](https://unclutterapp.com/) - an excellent Mac productivity app.

Built with ❤️ using Swift and SwiftUI.

---

## 🚀 Ready to Build?

1. Run `./setup.sh` for guided setup
2. Or follow **[BUILD_GUIDE.md](BUILD_GUIDE.md)**
3. See **[QUICKSTART.md](QUICKSTART.md)** for usage

**Questions?** Check the documentation files or code comments.

---

**Happy coding! 🎉**