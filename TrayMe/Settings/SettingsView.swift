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
            Section {
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
            } header: {
                Label("Activation", systemImage: "bolt.fill")
                    .font(.headline)
            }
            
            Section {
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
                        .font(.system(.body, design: .rounded).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .trailing)
                }
            } header: {
                Label("Appearance", systemImage: "paintbrush.fill")
                    .font(.headline)
            }
            
            Section {
                HStack {
                    Text("Version:")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
                
                Text("TrayMe — Your productivity tray")
                    .foregroundStyle(.secondary)
            } header: {
                Label("About", systemImage: "info.circle.fill")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }
}

struct ClipboardSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        Form {
            Section {
                Toggle("Enable clipboard manager", isOn: $settings.clipboardEnabled)
                
                HStack {
                    Text("Max history items:")
                    Slider(value: Binding(
                        get: { Double(settings.clipboardMaxHistory) },
                        set: { settings.clipboardMaxHistory = Int($0) }
                    ), in: 10...500, step: 10)
                    Text("\(settings.clipboardMaxHistory)")
                        .font(.system(.body, design: .rounded).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
                .disabled(!settings.clipboardEnabled)
                
                Toggle("Ignore password managers", isOn: $settings.ignorePasswordManagers)
                    .help("Don't track clipboard when copying from 1Password, LastPass, etc.")
                    .disabled(!settings.clipboardEnabled)
            } header: {
                Label("Clipboard Manager", systemImage: "doc.on.clipboard.fill")
                    .font(.headline)
            }
            
            Section {
                Label("Clipboard data is stored locally on your Mac", systemImage: "lock.shield.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                
                Label("No data is sent to external servers", systemImage: "network.slash")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } header: {
                Label("Privacy", systemImage: "hand.raised.fill")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }
}

struct FilesSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        Form {
            Section {
                Toggle("Enable files hub", isOn: $settings.filesEnabled)
                
                HStack {
                    Text("Max stored files:")
                    Slider(value: Binding(
                        get: { Double(settings.filesMaxStorage) },
                        set: { settings.filesMaxStorage = Int($0) }
                    ), in: 10...100, step: 5)
                    Text("\(settings.filesMaxStorage)")
                        .font(.system(.body, design: .rounded).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
                .disabled(!settings.filesEnabled)
            } header: {
                Label("Files Hub", systemImage: "folder.fill")
                    .font(.headline)
            }
            
            Section {
                Label("Files are referenced, not copied", systemImage: "link")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                
                Label("Moving or deleting the original file will break the reference", systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } header: {
                Label("Storage", systemImage: "internaldrive.fill")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }
}

struct NotesSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    
    var body: some View {
        Form {
            Section {
                Toggle("Enable quick notes", isOn: $settings.notesEnabled)
                
                Toggle("Sync with iCloud", isOn: $settings.notesSyncWithiCloud)
                    .help("Sync notes across your Apple devices")
                    .disabled(!settings.notesEnabled || true)
            } header: {
                Label("Quick Notes", systemImage: "note.text")
                    .font(.headline)
            }
            
            Section {
                Label("Notes are stored locally in Application Support", systemImage: "folder.badge.gearshape")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } header: {
                Label("Storage", systemImage: "internaldrive.fill")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
        .padding(20)
    }
}
