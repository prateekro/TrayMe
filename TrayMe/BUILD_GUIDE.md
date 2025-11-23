# TrayMe - Unclutter Clone for macOS

A native macOS productivity app built with Swift and SwiftUI that combines clipboard management, file organization, and quick notes into a single, accessible panel.

## Features

### 🎯 Three Tools in One

1. **Clipboard Manager**
   - Automatically tracks your clipboard history
   - Search through past clips
   - Mark favorites for quick access
   - Smart filtering (ignores password managers)
   - Supports text, URLs, and code snippets

2. **Files Hub (Drop Zone)**
   - Temporary storage for files and folders
   - Drag and drop from Finder or Desktop
   - Quick access to recently used files
   - Drag files out to other applications
   - Visual grid with file previews

3. **Quick Notes**
   - Instant notepad without opening separate apps
   - Searchable note library
   - Pin important notes
   - Auto-save functionality
   - Clean, distraction-free editor

### ⚡ Key Interactions

- **Top-Screen Activation**: Move your mouse to the very top of the screen and the panel slides down
- **Hotkey**: Press `Cmd+Shift+U` to toggle the panel
- **Menu Bar Icon**: Click the tray icon in your menu bar
- **Universal Access**: Available across all Spaces and in full-screen apps
- **Smooth Animations**: Native macOS animations for a polished feel

## System Requirements

- macOS 12.0 (Monterey) or later
- Xcode 14.0 or later (for building from source)

## Installation

### Option 1: Build from Source

1. **Clone the repository:**
   ```bash
   cd /Users/prateekro/Documents/projects/TrayMe
   ```

2. **Open in Xcode:**
   ```bash
   open TrayMe.xcodeproj
   ```
   
   Or create a new Xcode project:
   - Open Xcode
   - File → New → Project
   - Choose "macOS" → "App"
   - Product Name: `TrayMe`
   - Interface: SwiftUI
   - Language: Swift
   - Bundle Identifier: `com.yourname.TrayMe`
   - Click "Next" and choose the TrayMe folder

3. **Add all Swift files to the project:**
   - Drag all `.swift` files into your Xcode project
   - Ensure they're added to the TrayMe target
   - Add `Info.plist` and `TrayMe.entitlements` to the project

4. **Configure signing:**
   - Select your project in Xcode
   - Go to "Signing & Capabilities"
   - Select your development team
   - Enable "App Sandbox" capability
   - Add "File Access" → "User Selected Files" (Read/Write)

5. **Build and run:**
   - Press `Cmd+R` or click the Run button
   - Grant accessibility permissions when prompted

### Option 2: Quick Setup Script

Create an Xcode project structure:

```bash
cd /Users/prateekro/Documents/projects/TrayMe

# This will organize all files for Xcode
mkdir -p TrayMe.xcodeproj
```

## First Launch Setup

When you first run TrayMe, you'll need to grant some permissions:

### 1. Accessibility Permissions (Required for Mouse Tracking)

- macOS will prompt you to grant accessibility permissions
- Go to: **System Settings** → **Privacy & Security** → **Accessibility**
- Enable the checkbox for TrayMe
- Restart the app after granting permission

### 2. File Access (Optional)

- Automatically granted when you drag files into the Files Hub
- No manual setup required

## Usage

### Activating TrayMe

1. **Mouse Activation**: Move your cursor to the very top of the screen and hold briefly
2. **Hotkey**: Press `Cmd+Shift+U`
3. **Menu Bar**: Click the tray icon

### Clipboard Manager

- Click any clipboard item to copy it again
- Click the star icon to mark as favorite
- Use the search bar to find specific clips
- Delete individual items with the trash icon
- Clear entire history with "Clear History"

### Files Hub

- **Add files**: Drag files from Finder or Desktop into the panel
- **Use files**: Drag files out to email, messages, or other apps
- **Open files**: Click to open, folder icon to reveal in Finder
- **Remove**: Click trash icon to remove from TrayMe

### Quick Notes

- **New note**: Click the pencil icon or `Cmd+N`
- **Edit**: Click a note from the sidebar to edit
- **Pin**: Click the pin icon to keep important notes at top
- **Delete**: Click trash icon to remove
- **Search**: Use search bar to find notes by title or content

## Settings

Access settings via:
- Menu bar icon → Preferences
- Hotkey: `Cmd+,`
- In-panel settings button (gear icon)

### Available Settings

**General:**
- Enable/disable mouse activation
- Enable/disable hotkey activation
- Customize hotkey combination
- Choose default tab on launch
- Adjust panel size

**Clipboard:**
- Maximum history items (10-500)
- Ignore password managers
- Enable/disable clipboard tracking

**Files:**
- Maximum stored files (10-100)
- Enable/disable files hub

**Notes:**
- Enable/disable quick notes
- iCloud sync (coming soon)

## Architecture

### Technology Stack

- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Platform**: macOS (AppKit bridge for system features)
- **Persistence**: Local JSON storage
- **Performance**: Optimized with lazy loading and efficient clipboard polling

### Project Structure

```
TrayMe/
├── TrayMeApp.swift           # Main app entry point
├── Models/
│   ├── ClipboardItem.swift   # Clipboard data model
│   ├── FileItem.swift        # File reference model
│   └── Note.swift            # Note data model
├── Managers/
│   ├── ClipboardManager.swift # Clipboard monitoring & storage
│   ├── FilesManager.swift     # File management
│   └── NotesManager.swift     # Notes CRUD operations
├── UI/
│   ├── MainPanel.swift        # Custom NSPanel window
│   ├── MainPanelView.swift    # SwiftUI main view
│   └── Views/
│       ├── ClipboardView.swift
│       ├── FilesView.swift
│       └── NotesView.swift
├── Utilities/
│   └── MouseTracker.swift     # Top-screen mouse detection
├── Settings/
│   ├── AppSettings.swift      # UserDefaults wrapper
│   └── SettingsView.swift     # Settings UI
├── Info.plist
└── TrayMe.entitlements
```

### Why Swift & SwiftUI?

✅ **Performance**: Native compilation, minimal memory footprint  
✅ **System Integration**: Direct access to macOS APIs  
✅ **Modern UI**: SwiftUI provides smooth, native macOS look  
✅ **Resource Efficiency**: Low CPU and battery usage  
✅ **Fresh UI**: Native blur effects, SF Symbols, and animations

## Building for Distribution

1. **Archive the app:**
   - In Xcode: Product → Archive
   - Wait for the archive to complete

2. **Distribute:**
   - Window → Organizer
   - Select your archive
   - Click "Distribute App"
   - Choose distribution method:
     - "Copy App" for personal use
     - "Developer ID" for distribution outside Mac App Store
     - "Mac App Store" for App Store submission

3. **Notarization** (for distribution):
   ```bash
   xcrun notarytool submit TrayMe.zip --apple-id your@email.com --team-id TEAMID --password app-specific-password
   ```

## Development

### Running in Development

```bash
# Open project
open TrayMe.xcodeproj

# Or build from command line
xcodebuild -scheme TrayMe -configuration Debug
```

### Debugging

- **Clipboard not tracking**: Check accessibility permissions
- **Mouse tracking not working**: Verify accessibility access
- **Files not dragging**: Ensure sandbox entitlements are correct
- **App crashes on launch**: Check Console.app for crash logs

### Contributing

This is a personal project, but suggestions and improvements are welcome!

## Privacy & Security

- **All data stored locally** on your Mac
- **No analytics** or tracking
- **No network requests** (current version)
- **Sandbox protected** via macOS App Sandbox
- **Password manager filtering** to protect sensitive data

Data locations:
- Clipboard: `~/Library/Application Support/TrayMe/clipboard.json`
- Files: `~/Library/Application Support/TrayMe/files.json`
- Notes: `~/Library/Application Support/TrayMe/notes.json`

## Troubleshooting

### Mouse activation not working
- Go to System Settings → Privacy & Security → Accessibility
- Add TrayMe and enable the checkbox
- Restart TrayMe

### Clipboard not being tracked
- Check Settings → Clipboard → Enable clipboard manager
- Ensure app is running (check menu bar icon)

### Files not appearing after drag & drop
- Verify file permissions
- Check if files still exist at original location
- Try dragging from a different location

### App doesn't start
- Check Console.app for error messages
- Ensure macOS version is 12.0 or later
- Try resetting app: Delete app, remove `~/Library/Application Support/TrayMe`, reinstall

## Roadmap

- [ ] iCloud sync for notes
- [ ] Clipboard sync across devices
- [ ] Rich text support in notes
- [ ] Custom themes
- [ ] Keyboard shortcuts for all actions
- [ ] Import/export data
- [ ] Multiple workspaces
- [ ] Clipboard data encryption

## License

This is a personal project created for educational purposes.

## Credits

Inspired by [Unclutter](https://unclutterapp.com/) - an excellent productivity tool for macOS.

---

**Built with ❤️ using Swift and SwiftUI**
