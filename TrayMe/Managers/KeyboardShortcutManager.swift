//
//  KeyboardShortcutManager.swift
//  TrayMe
//
//  Manages custom keyboard shortcuts

import SwiftUI
import AppKit
import Carbon.HIToolbox

/// Represents a customizable keyboard shortcut
struct KeyboardShortcut: Codable, Identifiable, Equatable {
    let id: String
    var keyCode: UInt16
    var modifiers: NSEvent.ModifierFlags
    var isEnabled: Bool
    
    var displayString: String {
        var parts: [String] = []
        
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        
        parts.append(keyCodeToString(keyCode))
        
        return parts.joined()
    }
    
    private func keyCodeToString(_ keyCode: UInt16) -> String {
        switch keyCode {
        case UInt16(kVK_ANSI_A): return "A"
        case UInt16(kVK_ANSI_B): return "B"
        case UInt16(kVK_ANSI_C): return "C"
        case UInt16(kVK_ANSI_D): return "D"
        case UInt16(kVK_ANSI_E): return "E"
        case UInt16(kVK_ANSI_F): return "F"
        case UInt16(kVK_ANSI_G): return "G"
        case UInt16(kVK_ANSI_H): return "H"
        case UInt16(kVK_ANSI_I): return "I"
        case UInt16(kVK_ANSI_J): return "J"
        case UInt16(kVK_ANSI_K): return "K"
        case UInt16(kVK_ANSI_L): return "L"
        case UInt16(kVK_ANSI_M): return "M"
        case UInt16(kVK_ANSI_N): return "N"
        case UInt16(kVK_ANSI_O): return "O"
        case UInt16(kVK_ANSI_P): return "P"
        case UInt16(kVK_ANSI_Q): return "Q"
        case UInt16(kVK_ANSI_R): return "R"
        case UInt16(kVK_ANSI_S): return "S"
        case UInt16(kVK_ANSI_T): return "T"
        case UInt16(kVK_ANSI_U): return "U"
        case UInt16(kVK_ANSI_V): return "V"
        case UInt16(kVK_ANSI_W): return "W"
        case UInt16(kVK_ANSI_X): return "X"
        case UInt16(kVK_ANSI_Y): return "Y"
        case UInt16(kVK_ANSI_Z): return "Z"
        case UInt16(kVK_ANSI_0): return "0"
        case UInt16(kVK_ANSI_1): return "1"
        case UInt16(kVK_ANSI_2): return "2"
        case UInt16(kVK_ANSI_3): return "3"
        case UInt16(kVK_ANSI_4): return "4"
        case UInt16(kVK_ANSI_5): return "5"
        case UInt16(kVK_ANSI_6): return "6"
        case UInt16(kVK_ANSI_7): return "7"
        case UInt16(kVK_ANSI_8): return "8"
        case UInt16(kVK_ANSI_9): return "9"
        case UInt16(kVK_Space): return "Space"
        case UInt16(kVK_Return): return "↩"
        case UInt16(kVK_Tab): return "⇥"
        case UInt16(kVK_Delete): return "⌫"
        case UInt16(kVK_Escape): return "⎋"
        case UInt16(kVK_LeftArrow): return "←"
        case UInt16(kVK_RightArrow): return "→"
        case UInt16(kVK_UpArrow): return "↑"
        case UInt16(kVK_DownArrow): return "↓"
        case UInt16(kVK_F1): return "F1"
        case UInt16(kVK_F2): return "F2"
        case UInt16(kVK_F3): return "F3"
        case UInt16(kVK_F4): return "F4"
        case UInt16(kVK_F5): return "F5"
        case UInt16(kVK_F6): return "F6"
        case UInt16(kVK_F7): return "F7"
        case UInt16(kVK_F8): return "F8"
        case UInt16(kVK_F9): return "F9"
        case UInt16(kVK_F10): return "F10"
        case UInt16(kVK_F11): return "F11"
        case UInt16(kVK_F12): return "F12"
        default: return "?"
        }
    }
    
    // Custom Codable for NSEvent.ModifierFlags
    enum CodingKeys: String, CodingKey {
        case id, keyCode, modifiersRaw, isEnabled
    }
    
    init(id: String, keyCode: UInt16, modifiers: NSEvent.ModifierFlags, isEnabled: Bool = true) {
        self.id = id
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.isEnabled = isEnabled
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        keyCode = try container.decode(UInt16.self, forKey: .keyCode)
        let modifiersRaw = try container.decode(UInt.self, forKey: .modifiersRaw)
        modifiers = NSEvent.ModifierFlags(rawValue: modifiersRaw)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(modifiers.rawValue, forKey: .modifiersRaw)
        try container.encode(isEnabled, forKey: .isEnabled)
    }
}

/// Known shortcut actions
enum ShortcutAction: String, CaseIterable {
    case togglePanel = "toggle_panel"
    case switchToClipboard = "switch_clipboard"
    case switchToFiles = "switch_files"
    case switchToNotes = "switch_notes"
    case clearClipboardHistory = "clear_clipboard"
    case newNote = "new_note"
    case searchFocus = "search_focus"
    
    var displayName: String {
        switch self {
        case .togglePanel: return "Toggle TrayMe Panel"
        case .switchToClipboard: return "Switch to Clipboard"
        case .switchToFiles: return "Switch to Files"
        case .switchToNotes: return "Switch to Notes"
        case .clearClipboardHistory: return "Clear Clipboard History"
        case .newNote: return "New Note"
        case .searchFocus: return "Focus Search"
        }
    }
    
    var defaultShortcut: KeyboardShortcut {
        switch self {
        case .togglePanel:
            return KeyboardShortcut(
                id: rawValue,
                keyCode: UInt16(kVK_ANSI_U),
                modifiers: [.command, .control, .shift]
            )
        case .switchToClipboard:
            return KeyboardShortcut(
                id: rawValue,
                keyCode: UInt16(kVK_ANSI_1),
                modifiers: [.command]
            )
        case .switchToFiles:
            return KeyboardShortcut(
                id: rawValue,
                keyCode: UInt16(kVK_ANSI_2),
                modifiers: [.command]
            )
        case .switchToNotes:
            return KeyboardShortcut(
                id: rawValue,
                keyCode: UInt16(kVK_ANSI_3),
                modifiers: [.command]
            )
        case .clearClipboardHistory:
            return KeyboardShortcut(
                id: rawValue,
                keyCode: UInt16(kVK_Delete),
                modifiers: [.command, .shift]
            )
        case .newNote:
            return KeyboardShortcut(
                id: rawValue,
                keyCode: UInt16(kVK_ANSI_N),
                modifiers: [.command]
            )
        case .searchFocus:
            return KeyboardShortcut(
                id: rawValue,
                keyCode: UInt16(kVK_ANSI_F),
                modifiers: [.command]
            )
        }
    }
}

/// Reserved system shortcuts that cannot be used
struct ReservedShortcuts {
    static let reserved: Set<String> = [
        "⌘Q",  // Quit
        "⌘W",  // Close Window
        "⌘H",  // Hide
        "⌘M",  // Minimize
        "⌘,",  // Preferences
        "⌘C",  // Copy
        "⌘V",  // Paste
        "⌘X",  // Cut
        "⌘Z",  // Undo
        "⇧⌘Z", // Redo
        "⌘A",  // Select All
        "⌘S",  // Save
        "⌘P",  // Print
        "⌘O",  // Open
    ]
    
    static func isReserved(_ shortcut: KeyboardShortcut) -> Bool {
        return reserved.contains(shortcut.displayString)
    }
}

/// Manager for keyboard shortcuts
class KeyboardShortcutManager: ObservableObject {
    @Published var shortcuts: [String: KeyboardShortcut] = [:]
    
    private let saveKey = "TrayMe.KeyboardShortcuts"
    
    init() {
        loadShortcuts()
    }
    
    func loadShortcuts() {
        // Load saved shortcuts or use defaults
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([String: KeyboardShortcut].self, from: data) {
            shortcuts = decoded
        }
        
        // Ensure all actions have shortcuts (fill in defaults for missing ones)
        for action in ShortcutAction.allCases {
            if shortcuts[action.rawValue] == nil {
                shortcuts[action.rawValue] = action.defaultShortcut
            }
        }
    }
    
    func saveShortcuts() {
        if let data = try? JSONEncoder().encode(shortcuts) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }
    
    func updateShortcut(for action: ShortcutAction, keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
        let newShortcut = KeyboardShortcut(id: action.rawValue, keyCode: keyCode, modifiers: modifiers)
        
        // Check if reserved
        if ReservedShortcuts.isReserved(newShortcut) {
            return false
        }
        
        // Check for conflicts with other shortcuts
        for (key, existingShortcut) in shortcuts {
            if key != action.rawValue && existingShortcut.keyCode == keyCode && existingShortcut.modifiers == modifiers {
                return false
            }
        }
        
        shortcuts[action.rawValue] = newShortcut
        saveShortcuts()
        return true
    }
    
    func resetToDefaults() {
        for action in ShortcutAction.allCases {
            shortcuts[action.rawValue] = action.defaultShortcut
        }
        saveShortcuts()
    }
    
    func shortcut(for action: ShortcutAction) -> KeyboardShortcut {
        return shortcuts[action.rawValue] ?? action.defaultShortcut
    }
    
    func matches(event: NSEvent, action: ShortcutAction) -> Bool {
        guard let shortcut = shortcuts[action.rawValue], shortcut.isEnabled else {
            return false
        }
        
        let eventModifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        return event.keyCode == shortcut.keyCode && eventModifiers == shortcut.modifiers
    }
}
