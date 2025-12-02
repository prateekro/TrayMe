# TrayMe for Windows

A native Windows productivity app built with C# and WPF - ported from the original macOS version.

## 🎯 What is TrayMe?

TrayMe is a **3-in-1 productivity tool** that slides down from the top of your screen, giving you instant access to:

1. **📋 Clipboard Manager** - Never lose what you copied
2. **📁 Files Hub** - Temporary file storage & quick access  
3. **📝 Quick Notes** - Instant notepad without opening apps

## ✨ Features

### Clipboard Manager
- ✅ Automatic clipboard history tracking
- ✅ Search through past clips
- ✅ Favorites system for frequently used items
- ✅ Smart type detection (text, URLs, code)
- ✅ Password manager filtering for security

### Files Hub (Drop Zone)
- ✅ Drag & drop files from Explorer
- ✅ Drag files out to other apps
- ✅ File preview with thumbnails
- ✅ **Copy files** to storage or **reference** originals
- ✅ Visual badges (Green "Stored" vs Orange "Ref")
- ✅ Quick open or reveal in Explorer
- ✅ Copy image to clipboard
- ✅ **File limit enforcement** (up to 100 files)

### Quick Notes
- ✅ Instant note creation
- ✅ Auto-save functionality
- ✅ Full-text search
- ✅ Pin important notes
- ✅ Clean, distraction-free editor

### System Integration
- ✅ Global hotkey (Ctrl+Shift+U)
- ✅ System tray icon
- ✅ Panel slides from top of screen
- ✅ Click outside to close

## 🚀 Quick Start

### Prerequisites
- Windows 10/11
- .NET 8.0 SDK or later
- Visual Studio 2022 (recommended)

### Build and Run

```bash
cd TrayMe.Windows
dotnet restore
dotnet build
dotnet run
```

Or open `TrayMe.Windows.csproj` in Visual Studio and press F5.

## 🎮 Usage

### Activation Methods
| Method | Action |
|--------|--------|
| **Hotkey** | Press `Ctrl+Shift+U` |
| **System Tray** | Double-click tray icon |
| **Context Menu** | Right-click tray icon → Show Panel |

### Shortcuts
| Shortcut | Action |
|----------|--------|
| **Ctrl+Shift+U** | Toggle panel |
| **Click outside** | Close panel |
| **Drag & Drop** | Add files to Files Hub |

## ⚙️ Settings

Access via system tray → Settings

- **General:** Panel size, activation options
- **Clipboard:** History limit, password filtering
- **Files:** Maximum stored files
- **Notes:** Enable/disable

## 📂 Data Location

All data is stored locally:
```
%APPDATA%\TrayMe\
├── clipboard.json
├── files.json
├── notes.json
├── settings.json
└── StoredFiles\
```

## 🔒 Privacy & Security

- ✅ All data stored **locally** on your PC
- ✅ **No network requests** or telemetry
- ✅ **Password manager filtering** built-in
- ✅ Only accesses files you explicitly drag in

## 🏗️ Architecture

**Language:** C# 12  
**Framework:** .NET 8.0  
**UI Framework:** WPF (Windows Presentation Foundation)  
**Platform:** Windows 10/11

### Project Structure
```
TrayMe.Windows/
├── App.xaml                    # App entry point
├── MainWindow.xaml             # Main panel window
├── Models/                     # Data models
│   ├── ClipboardItem.cs
│   ├── FileItem.cs
│   └── Note.cs
├── Managers/                   # Business logic
│   ├── ClipboardManager.cs
│   ├── FilesManager.cs
│   ├── NotesManager.cs
│   └── AppSettings.cs
├── Views/                      # UI components
│   ├── ClipboardView.xaml
│   ├── FilesView.xaml
│   ├── NotesView.xaml
│   └── SettingsWindow.xaml
├── Styles/                     # UI styles
│   └── Styles.xaml
└── Utilities/                  # Helper classes
    └── Converters.cs
```

## 📦 Dependencies

- **Hardcodet.NotifyIcon.Wpf** - System tray icon support
- **Newtonsoft.Json** - JSON serialization
- **NHotkey.Wpf** - Global hotkey registration

## 🗺️ Feature Parity with macOS Version

| Feature | Status |
|---------|--------|
| Clipboard Manager | ✅ Complete |
| Files Hub | ✅ Complete |
| File Storage Options | ✅ Complete |
| Quick Notes | ✅ Complete |
| Hotkey support | ✅ Complete |
| System tray icon | ✅ Complete |
| Drag & drop | ✅ Complete |
| Search | ✅ Complete |
| Favorites | ✅ Complete |
| Settings | ✅ Complete |

## 📝 License

Personal/Educational project - Built as an Unclutter clone for learning purposes.

---

**Happy productivity! 🎉**
