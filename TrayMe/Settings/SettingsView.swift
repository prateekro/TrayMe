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
    @State private var showExcludedAppsSheet = false
    
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
            
            Section(header: Text("Excluded Apps").font(.headline)) {
                Text("Clipboard won't be tracked when copying from these apps:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("\(settings.excludedAppBundleIds.count) apps excluded")
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Manage...") {
                        showExcludedAppsSheet = true
                    }
                    .disabled(!settings.clipboardEnabled)
                }
                
                Button("Add Default Password Managers") {
                    settings.excludeAllDefaultApps()
                }
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
        .sheet(isPresented: $showExcludedAppsSheet) {
            ExcludedAppsView()
                .environmentObject(settings)
        }
    }
}

/// View for managing excluded apps
struct ExcludedAppsView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var customBundleId = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Excluded Apps")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }
            .padding()
            
            Divider()
            
            // Default apps section
            VStack(alignment: .leading, spacing: 8) {
                Text("Common Password Managers")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(AppSettings.defaultExcludedApps) { app in
                            ExcludedAppRow(
                                app: app,
                                isExcluded: settings.excludedAppBundleIds.contains(app.bundleId),
                                onToggle: { isExcluded in
                                    if isExcluded {
                                        settings.excludeApp(app.bundleId)
                                    } else {
                                        settings.includeApp(app.bundleId)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(maxHeight: 200)
            }
            
            Divider()
            
            // Custom apps section
            VStack(alignment: .leading, spacing: 8) {
                Text("Custom Apps (Bundle ID)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                HStack {
                    TextField("com.example.app", text: $customBundleId)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Add") {
                        if !customBundleId.isEmpty {
                            settings.excludeApp(customBundleId)
                            customBundleId = ""
                        }
                    }
                    .disabled(customBundleId.isEmpty)
                }
                .padding(.horizontal)
                
                // List of custom excluded apps
                let customApps = settings.excludedAppBundleIds.filter { bundleId in
                    !AppSettings.defaultExcludedApps.contains(where: { $0.bundleId == bundleId })
                }
                
                if !customApps.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(Array(customApps), id: \.self) { bundleId in
                                HStack {
                                    Text(bundleId)
                                        .font(.system(size: 12, design: .monospaced))
                                    Spacer()
                                    Button(action: {
                                        settings.includeApp(bundleId)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(6)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(maxHeight: 100)
                }
            }
            
            Spacer()
        }
        .frame(width: 400, height: 450)
    }
}

struct ExcludedAppRow: View {
    let app: ExcludedApp
    let isExcluded: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack {
            Toggle(isOn: Binding(
                get: { isExcluded },
                set: { onToggle($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.system(size: 13))
                    Text(app.bundleId)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.checkbox)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
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
