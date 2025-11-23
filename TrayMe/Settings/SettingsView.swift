//
//  SettingsView.swift
//  TrayMe
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .environmentObject(settings)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
            
            ClipboardSettingsView()
                .environmentObject(settings)
                .tabItem {
                    Label("Clipboard", systemImage: "doc.on.clipboard")
                }
            
            FilesSettingsView()
                .environmentObject(settings)
                .tabItem {
                    Label("Files", systemImage: "folder")
                }
            
            NotesSettingsView()
                .environmentObject(settings)
                .tabItem {
                    Label("Notes", systemImage: "note.text")
                }
        }
        .frame(width: 500, height: 400)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        Form {
            Section(header: Text("Activation").font(.headline)) {
                Toggle("Enable mouse activation at top of screen", isOn: $settings.enableMouseActivation)
                    .help("Move mouse to top of screen to show TrayMe")
                
                Toggle("Enable hotkey activation", isOn: $settings.enableHotkeyActivation)
                    .help("Use keyboard shortcut to toggle TrayMe")
                
                HStack {
                    Text("Hotkey:")
                    TextField("Modifiers", text: $settings.hotkeyModifiers)
                        .frame(width: 100)
                    Text("+")
                    TextField("Key", text: $settings.hotkeyKey)
                        .frame(width: 50)
                }
                .disabled(!settings.enableHotkeyActivation)
            }
            
            Section(header: Text("Appearance").font(.headline)) {
                Picker("Default tab:", selection: $settings.defaultTab) {
                    Text("Clipboard").tag("clipboard")
                    Text("Files").tag("files")
                    Text("Notes").tag("notes")
                }
                .pickerStyle(.radioGroup)
                
                HStack {
                    Text("Panel size:")
                    Slider(value: $settings.panelWidth, in: 600...1400, step: 50)
                    Text("\(Int(settings.panelWidth))px")
                }
            }
            
            Section(header: Text("About").font(.headline)) {
                HStack {
                    Text("Version:")
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("TrayMe - Unclutter Clone")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
    }
}

struct ClipboardSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        Form {
            Section(header: Text("Clipboard Manager").font(.headline)) {
                Toggle("Enable clipboard manager", isOn: $settings.clipboardEnabled)
                
                HStack {
                    Text("Max history items:")
                    Slider(value: Binding(
                        get: { Double(settings.clipboardMaxHistory) },
                        set: { settings.clipboardMaxHistory = Int($0) }
                    ), in: 10...500, step: 10)
                    Text("\(settings.clipboardMaxHistory)")
                }
                .disabled(!settings.clipboardEnabled)
                
                Toggle("Ignore password managers", isOn: $settings.ignorePasswordManagers)
                    .help("Don't track clipboard when copying from 1Password, LastPass, etc.")
                    .disabled(!settings.clipboardEnabled)
            }
            
            Section(header: Text("Privacy").font(.headline)) {
                Text("Clipboard data is stored locally on your Mac")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("No data is sent to external servers")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
    }
}

struct FilesSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        Form {
            Section(header: Text("Files Hub").font(.headline)) {
                Toggle("Enable files hub", isOn: $settings.filesEnabled)
                
                HStack {
                    Text("Max stored files:")
                    Slider(value: Binding(
                        get: { Double(settings.filesMaxStorage) },
                        set: { settings.filesMaxStorage = Int($0) }
                    ), in: 10...100, step: 5)
                    Text("\(settings.filesMaxStorage)")
                }
                .disabled(!settings.filesEnabled)
            }
            
            Section(header: Text("Storage").font(.headline)) {
                Text("Files are referenced, not copied")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Moving or deleting the original file will break the reference")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
    }
}

struct NotesSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        Form {
            Section(header: Text("Quick Notes").font(.headline)) {
                Toggle("Enable quick notes", isOn: $settings.notesEnabled)
                
                Toggle("Sync with iCloud", isOn: $settings.notesSyncWithiCloud)
                    .help("Sync notes across your Apple devices")
                    .disabled(!settings.notesEnabled || true) // iCloud sync not yet implemented
            }
            
            Section(header: Text("Storage").font(.headline)) {
                Text("Notes are stored locally in Application Support")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
    }
}
