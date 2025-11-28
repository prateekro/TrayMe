//
//  SnippetView.swift
//  TrayMe
//
//  Main snippet list view with search and categories

import SwiftUI

struct SnippetView: View {
    @EnvironmentObject var manager: SnippetManager
    @State private var showingEditor = false
    @State private var editingSnippet: Snippet?
    @State private var showingImportExport = false
    @State private var hoveredSnippet: UUID?
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar with categories
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search snippets...", text: $manager.searchText)
                        .textFieldStyle(.plain)
                    
                    if !manager.searchText.isEmpty {
                        Button(action: { manager.searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .padding()
                
                // Categories list
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        // All snippets
                        CategoryRow(
                            name: "All Snippets",
                            icon: "tray.full",
                            count: manager.snippets.count,
                            isSelected: manager.searchText.isEmpty
                        )
                        .onTapGesture {
                            manager.searchText = ""
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Categories
                        ForEach(manager.categories) { category in
                            CategoryRow(
                                name: category.name,
                                icon: category.icon,
                                count: manager.snippets.filter { $0.category == category.name }.count,
                                isSelected: manager.searchText == "category:\(category.name)"
                            )
                            .onTapGesture {
                                manager.searchText = "category:\(category.name)"
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Footer actions
                HStack {
                    Button(action: { showingImportExport = true }) {
                        Image(systemName: "square.and.arrow.up.on.square")
                    }
                    .buttonStyle(.plain)
                    .help("Import/Export snippets")
                    
                    Spacer()
                    
                    Text("\(manager.snippets.count) snippets")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            }
            .frame(width: 200)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // Main snippet list
            VStack(spacing: 0) {
                // Header with add button
                HStack {
                    Text("Snippets")
                        .font(.system(size: 14, weight: .semibold))
                    
                    Spacer()
                    
                    Toggle("Enabled", isOn: $manager.isEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    
                    Button(action: {
                        editingSnippet = nil
                        showingEditor = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("Add new snippet")
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Snippets list
                if manager.filteredSnippets.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "text.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No snippets")
                            .font(.system(size: 16, weight: .medium))
                        
                        Text("Create a snippet to quickly expand text")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Button("Create Snippet") {
                            editingSnippet = nil
                            showingEditor = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(manager.filteredSnippets) { snippet in
                                SnippetRow(
                                    snippet: snippet,
                                    isHovered: hoveredSnippet == snippet.id,
                                    isSelected: manager.selectedSnippet?.id == snippet.id
                                )
                                .onHover { hovering in
                                    hoveredSnippet = hovering ? snippet.id : nil
                                }
                                .onTapGesture {
                                    manager.selectedSnippet = snippet
                                }
                                .onTapGesture(count: 2) {
                                    editingSnippet = snippet
                                    showingEditor = true
                                }
                            }
                        }
                        .padding(8)
                    }
                }
            }
            
            // Detail panel
            if let selectedSnippet = manager.selectedSnippet {
                Divider()
                
                SnippetDetailPanel(
                    snippet: selectedSnippet,
                    onEdit: {
                        editingSnippet = selectedSnippet
                        showingEditor = true
                    },
                    onDelete: {
                        manager.deleteSnippet(selectedSnippet)
                    }
                )
                .frame(width: 280)
            }
        }
        .sheet(isPresented: $showingEditor) {
            SnippetEditorView(snippet: editingSnippet)
                .environmentObject(manager)
        }
        .sheet(isPresented: $showingImportExport) {
            ImportExportView()
                .environmentObject(manager)
        }
    }
}

// MARK: - Category Row

struct CategoryRow: View {
    let name: String
    let icon: String
    let count: Int
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(isSelected ? .accentColor : .secondary)
            
            Text(name)
                .font(.system(size: 13))
            
            Spacer()
            
            Text("\(count)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(4)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
    }
}

// MARK: - Snippet Row

struct SnippetRow: View {
    @EnvironmentObject var manager: SnippetManager
    let snippet: Snippet
    let isHovered: Bool
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Trigger badge
            Text(snippet.trigger)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor)
                .cornerRadius(4)
            
            // Content preview
            VStack(alignment: .leading, spacing: 2) {
                Text(snippet.preview)
                    .font(.system(size: 13))
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    if let category = snippet.category {
                        Text(category)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    if snippet.usageCount > 0 {
                        Text("Used \(snippet.usageCount)×")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Actions on hover
            if isHovered {
                HStack(spacing: 8) {
                    Button(action: {
                        // Copy expansion to clipboard
                        let expansion = snippet.expand()
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(expansion, forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("Copy expansion")
                    
                    Button(action: {
                        manager.deleteSnippet(snippet)
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Delete")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.2) :
                      (isHovered ? Color.accentColor.opacity(0.1) : Color.clear))
        )
    }
}

// MARK: - Snippet Detail Panel

struct SnippetDetailPanel: View {
    @EnvironmentObject var manager: SnippetManager
    let snippet: Snippet
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Details")
                    .font(.system(size: 14, weight: .semibold))
                
                Spacer()
                
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
                .help("Edit snippet")
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Trigger
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Trigger")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Text(snippet.trigger)
                            .font(.system(size: 14, design: .monospaced))
                            .padding(8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                    }
                    
                    // Expansion
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Expansion")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Text(snippet.expansion)
                            .font(.system(size: 12))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                    }
                    
                    // Variables
                    if !snippet.variables.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Variables")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            ForEach(snippet.variables, id: \.self) { variable in
                                HStack {
                                    Text(variable)
                                        .font(.system(size: 11, design: .monospaced))
                                    
                                    Spacer()
                                    
                                    Text(BuiltInVariable(rawValue: variable)?.displayName ?? "Custom")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                .padding(6)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(4)
                            }
                        }
                    }
                    
                    // Stats
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Statistics")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("Uses:")
                            Spacer()
                            Text("\(snippet.usageCount)")
                                .foregroundColor(.secondary)
                        }
                        .font(.system(size: 12))
                        
                        if let lastUsed = snippet.lastUsed {
                            HStack {
                                Text("Last used:")
                                Spacer()
                                Text(lastUsed, style: .relative)
                                    .foregroundColor(.secondary)
                            }
                            .font(.system(size: 12))
                        }
                        
                        HStack {
                            Text("Created:")
                            Spacer()
                            Text(snippet.createdAt, style: .date)
                                .foregroundColor(.secondary)
                        }
                        .font(.system(size: 12))
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Actions
            HStack {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
                
                Spacer()
                
                Button(action: {
                    let expansion = snippet.expand()
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(expansion, forType: .string)
                }) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        }
    }
}

// MARK: - Import/Export View

struct ImportExportView: View {
    @EnvironmentObject var manager: SnippetManager
    @Environment(\.dismiss) private var dismiss
    @State private var importMessage = ""
    @State private var showingFilePicker = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Import / Export Snippets")
                .font(.title2)
            
            HStack(spacing: 20) {
                // Export
                VStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 32))
                        .foregroundColor(.accentColor)
                    
                    Text("Export")
                        .font(.headline)
                    
                    Text("Save all snippets to a JSON file")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Export Snippets") {
                        exportSnippets()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                
                // Import
                VStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 32))
                        .foregroundColor(.accentColor)
                    
                    Text("Import")
                        .font(.headline)
                    
                    Text("Load snippets from a JSON file")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Import Snippets") {
                        showingFilePicker = true
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }
            
            if !importMessage.isEmpty {
                Text(importMessage)
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            Button("Close") {
                dismiss()
            }
        }
        .padding(30)
        .frame(width: 400)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
    }
    
    private func exportSnippets() {
        guard let data = manager.exportSnippets() else { return }
        
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "TrayMe-Snippets.json"
        savePanel.allowedContentTypes = [.json]
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            try? data.write(to: url)
        }
    }
    
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first,
                  let data = try? Data(contentsOf: url) else {
                importMessage = "Failed to read file"
                return
            }
            
            let count = manager.importSnippets(from: data)
            importMessage = "Imported \(count) snippets"
            
        case .failure(let error):
            importMessage = "Error: \(error.localizedDescription)"
        }
    }
}
