#!/bin/bash

# TrayMe - Quick Setup Script
# This script helps set up an Xcode project for TrayMe

echo "🚀 TrayMe - Xcode Project Setup"
echo "================================"
echo ""

PROJECT_DIR="/Users/prateekro/Documents/projects/TrayMe"
PROJECT_NAME="TrayMe"

cd "$PROJECT_DIR" || exit 1

echo "📁 Current directory: $PROJECT_DIR"
echo ""

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode is not installed. Please install Xcode from the Mac App Store."
    exit 1
fi

echo "✅ Xcode detected"
echo ""

# Create directory structure
echo "📂 Creating directory structure..."
mkdir -p "$PROJECT_DIR/Models"
mkdir -p "$PROJECT_DIR/Managers"
mkdir -p "$PROJECT_DIR/UI/Views"
mkdir -p "$PROJECT_DIR/Utilities"
mkdir -p "$PROJECT_DIR/Settings"
mkdir -p "$PROJECT_DIR/Resources"

echo "✅ Directory structure created"
echo ""

# Check if all required files exist
echo "🔍 Checking for required files..."
required_files=(
    "TrayMeApp.swift"
    "Models/ClipboardItem.swift"
    "Models/FileItem.swift"
    "Models/Note.swift"
    "Managers/ClipboardManager.swift"
    "Managers/FilesManager.swift"
    "Managers/NotesManager.swift"
    "UI/MainPanel.swift"
    "UI/MainPanelView.swift"
    "UI/Views/ClipboardView.swift"
    "UI/Views/FilesView.swift"
    "UI/Views/NotesView.swift"
    "Utilities/MouseTracker.swift"
    "Settings/AppSettings.swift"
    "Settings/SettingsView.swift"
    "Info.plist"
    "TrayMe.entitlements"
)

missing_files=()
for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        missing_files+=("$file")
    fi
done

if [ ${#missing_files[@]} -eq 0 ]; then
    echo "✅ All required files present"
else
    echo "⚠️  Missing files:"
    for file in "${missing_files[@]}"; do
        echo "   - $file"
    done
fi
echo ""

# Instructions for Xcode setup
echo "📋 Next Steps:"
echo ""
echo "1. Open Xcode"
echo "2. Click 'Create a new Xcode project'"
echo "3. Choose macOS → App"
echo "4. Enter the following details:"
echo "   - Product Name: TrayMe"
echo "   - Team: (Select your team)"
echo "   - Organization Identifier: com.yourname"
echo "   - Bundle Identifier: com.yourname.TrayMe"
echo "   - Interface: SwiftUI"
echo "   - Language: Swift"
echo "   - Use Core Data: NO"
echo "   - Include Tests: NO"
echo "5. Choose this folder as the location: $PROJECT_DIR"
echo "6. When Xcode opens:"
echo "   a. Delete the default ContentView.swift and TrayMeApp.swift (Xcode's version)"
echo "   b. Right-click on TrayMe folder in sidebar → Add Files to TrayMe"
echo "   c. Select ALL .swift files in this directory"
echo "   d. Ensure 'Copy items if needed' is UNCHECKED"
echo "   e. Ensure 'Create groups' is selected"
echo "   f. Add Info.plist and TrayMe.entitlements"
echo ""
echo "7. Configure the project:"
echo "   a. Select TrayMe project in sidebar"
echo "   b. Go to 'Signing & Capabilities' tab"
echo "   c. Enable 'App Sandbox'"
echo "   d. Under 'File Access', enable 'User Selected Files' (Read/Write)"
echo "   e. Under 'Info' tab, set deployment target to macOS 12.0 or later"
echo ""
echo "8. Build and Run:"
echo "   - Press Cmd+R"
echo "   - Grant accessibility permissions when prompted"
echo ""
echo "📖 For detailed instructions, see BUILD_GUIDE.md"
echo ""
echo "✨ Happy coding!"
