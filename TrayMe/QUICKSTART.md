# TrayMe - Quick Start Guide

## 🚀 Getting Started in 5 Minutes

### Step 1: Open in Xcode

```bash
cd /Users/prateekro/Documents/projects/TrayMe
./setup.sh  # Follow the printed instructions
```

**OR manually:**

1. Open Xcode
2. Create New Project → macOS → App
3. Name: `TrayMe`, Interface: SwiftUI, Language: Swift
4. Save to: `/Users/prateekro/Documents/projects/TrayMe`

### Step 2: Add Files to Project

1. In Xcode, delete the auto-generated `TrayMeApp.swift` and `ContentView.swift`
2. Right-click on TrayMe folder → "Add Files to TrayMe..."
3. Select ALL `.swift` files in the directory
4. **Uncheck** "Copy items if needed"
5. **Check** "Create groups"
6. Add `Info.plist` and `TrayMe.entitlements`

### Step 3: Configure Project

1. Select project in sidebar → "Signing & Capabilities"
2. Choose your Team
3. Click "+ Capability" → Add "App Sandbox"
4. Under "File Access" → Enable "User Selected Files" (Read/Write)
5. Set minimum deployment target to macOS 12.0

### Step 4: Build & Run

Press `Cmd+R` → Grant accessibility when prompted → Enjoy!

---

## 📖 Usage Guide

### Opening TrayMe

| Method | Action |
|--------|--------|
| **Mouse** | Move cursor to top of screen, hold briefly |
| **Hotkey** | Press `Cmd+Shift+U` |
| **Menu Bar** | Click tray icon |

### Clipboard Manager

| Action | How To |
|--------|--------|
| Copy again | Click any item |
| Add to favorites | Click star icon |
| Delete item | Click trash icon |
| Clear all | "Clear History" button |
| Search | Type in search bar |

### Files Hub

| Action | How To |
|--------|--------|
| Add files | Drag from Finder/Desktop |
| Use files | Drag out to other apps |
| Open file | Click file card |
| Show in Finder | Click folder icon |
| Remove | Click trash icon |

### Quick Notes

| Action | How To |
|--------|--------|
| New note | Click pencil icon |
| Edit note | Click note in sidebar |
| Pin note | Click pin icon |
| Delete note | Click trash icon |
| Search | Type in search bar |

---

## ⚙️ Settings

Access via menu bar → Preferences or `Cmd+,`

### General Settings
- ✅ Enable mouse activation
- ✅ Enable hotkey activation  
- 🎹 Customize hotkey
- 🎨 Adjust panel size
- 📑 Set default tab

### Clipboard Settings
- 📊 Max history (10-500 items)
- 🔒 Ignore password managers
- ✅ Enable/disable tracking

### Files Settings
- 📦 Max files (10-100)
- ✅ Enable/disable files hub

### Notes Settings
- ✅ Enable/disable notes
- ☁️ iCloud sync (coming soon)

---

## 🔧 Troubleshooting

### Mouse activation not working
```
1. System Settings → Privacy & Security → Accessibility
2. Find TrayMe and enable
3. Restart app
```

### Clipboard not tracking
```
1. Check: Settings → Clipboard → "Enable clipboard manager"
2. Ensure app is running (menu bar icon visible)
3. Test by copying some text
```

### Build errors in Xcode
```
1. Clean build folder: Cmd+Shift+K
2. Delete derived data: Cmd+Shift+Delete
3. Restart Xcode
4. Check all .swift files are in the target
```

### App won't launch
```
1. Check Console.app for errors
2. Verify macOS 12.0+ 
3. Reset: Delete app + ~/Library/Application Support/TrayMe
```

---

## 🎯 Keyboard Shortcuts (In-App)

| Shortcut | Action |
|----------|--------|
| `Cmd+Shift+U` | Toggle panel |
| `Cmd+,` | Open settings |
| `Cmd+N` | New note (in Notes tab) |
| `Cmd+F` | Focus search bar |
| `Cmd+W` | Close panel |
| `Esc` | Close panel |

---

## 📂 Data Locations

All data stored locally:

```
~/Library/Application Support/TrayMe/
├── clipboard.json    # Clipboard history
├── files.json        # File references  
└── notes.json        # All notes
```

To backup: Copy entire `TrayMe` folder  
To reset: Delete folder and restart app

---

## 🎨 Customization Tips

### Panel Size
- Settings → General → Panel size slider
- Default: 900x400
- Range: 600-1400 wide

### Clipboard History
- Settings → Clipboard → Max history
- Default: 100 items
- Range: 10-500

### Disable Features
- Settings → Toggle off unused panels
- Reduces memory usage

---

## 🐛 Known Limitations

- ⚠️ iCloud sync not yet implemented
- ⚠️ No rich text in notes (plain text only)
- ⚠️ File references break if original moved/deleted
- ⚠️ Requires accessibility permissions for mouse tracking

---

## 💡 Pro Tips

1. **Pin important notes** to keep them at the top
2. **Use favorites** for frequently copied text
3. **Search is instant** - just start typing
4. **Drag files** directly from TrayMe to email/messages
5. **Works in full-screen apps** - try it!
6. **Multi-monitor support** - opens on active screen

---

## 📞 Need Help?

1. Check `BUILD_GUIDE.md` for detailed instructions
2. See `PROJECT_STRUCTURE.md` for architecture details
3. Check Console.app for error messages
4. Verify all permissions are granted

---

**Happy productivity! 🎉**
