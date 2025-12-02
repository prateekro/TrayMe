//
//  ClipboardView.swift
//  TrayMe
//

import SwiftUI

struct ClipboardView: View {
    @EnvironmentObject var manager: ClipboardManager
    @State private var hoveredItem: UUID?
    @State private var selectedItem: ClipboardItem?
    @State private var editedContent: String = ""
    @State private var saveWorkItem: DispatchWorkItem?
    @State private var showExportSheet = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Main list
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search clipboard...", text: $manager.searchText)
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
            
            // Favorites section
            if !manager.favorites.isEmpty && manager.searchText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Favorites")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(manager.favorites) { item in
                                FavoriteClipCard(item: item, selectedItem: $selectedItem, editedContent: $editedContent)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 80)
                }
                .padding(.bottom, 8)
            }
            
            // Clipboard history
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(manager.filteredItems) { item in
                        ClipboardItemRow(
                            item: item,
                            isHovered: hoveredItem == item.id,
                            isSelected: selectedItem?.id == item.id
                        )
                        .contentShape(Rectangle()) // Make entire row clickable
                        .onHover { hovering in
                            hoveredItem = hovering ? item.id : nil
                        }
                        .onTapGesture {
                            selectItem(item)
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            
            // Footer
            HStack {
                Text("\(manager.items.count) items")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: { showExportSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export")
                    }
                    .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                
                Button("Clear History") {
                    manager.clearHistory()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.red)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            }
            
            // Detail/Edit panel
            if let item = selectedItem {
                Divider()
                
                ClipboardDetailView(
                    item: item,
                    editedContent: $editedContent,
                    onClose: {
                        // Cancel pending save and save immediately
                        saveWorkItem?.cancel()
                        if let item = selectedItem {
                            manager.updateItemContent(item, newContent: editedContent)
                        }
                        selectedItem = nil
                    },
                    onSave: {
                        // Cancel pending save and save immediately
                        saveWorkItem?.cancel()
                        manager.updateItemContent(item, newContent: editedContent)
                        selectedItem = nil
                    },
                    onContentChange: {
                        // Debounced auto-save
                        saveWorkItem?.cancel()
                        let workItem = DispatchWorkItem { [weak manager] in
                            manager?.updateItemContent(item, newContent: editedContent)
                        }
                        saveWorkItem = workItem
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
                    }
                )
                .frame(width: 300)
            }
        }
        .sheet(isPresented: $showExportSheet) {
            ExportHistoryView(manager: manager)
        }
    }
    
    func selectItem(_ item: ClipboardItem) {
        selectedItem = item
        editedContent = item.content
        // Copy to clipboard when selecting
        manager.copyToClipboard(item)
    }
}

struct ClipboardItemRow: View {
    @EnvironmentObject var manager: ClipboardManager
    let item: ClipboardItem
    let isHovered: Bool
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Category icon with badge
            ZStack {
                Image(systemName: item.category.icon)
                    .foregroundColor(colorForCategory(item.category))
                    .frame(width: 20)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(item.displayContent)
                        .font(.system(size: 13))
                        .lineLimit(2)
                    
                    // Category badge
                    CategoryBadge(category: item.category)
                }
                
                HStack(spacing: 8) {
                    Text(item.timeAgo)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    if let sourceApp = item.sourceApp {
                        Text("from \(sourceApp.components(separatedBy: ".").last ?? sourceApp)")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Actions (visible on hover)
            if isHovered {
                HStack(spacing: 8) {
                    Button(action: {
                        manager.toggleFavorite(item)
                    }) {
                        Image(systemName: item.isFavorite ? "star.fill" : "star")
                            .foregroundColor(item.isFavorite ? .yellow : .secondary)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        manager.copyToClipboard(item)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        manager.deleteItem(item)
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
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
    
    func colorForCategory(_ category: ClipboardCategory) -> Color {
        switch category {
        case .text: return .secondary
        case .url: return .blue
        case .email: return .orange
        case .phone: return .green
        case .code: return .purple
        case .json: return .indigo
        case .address: return .red
        case .image: return .pink
        case .file: return .gray
        }
    }
}

/// Category badge view
struct CategoryBadge: View {
    let category: ClipboardCategory
    
    var body: some View {
        if category != .text {
            Text(category.rawValue.uppercased())
                .font(.system(size: 8, weight: .bold))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(backgroundColor)
                .foregroundColor(.white)
                .cornerRadius(3)
        }
    }
    
    var backgroundColor: Color {
        switch category {
        case .text: return .secondary
        case .url: return .blue
        case .email: return .orange
        case .phone: return .green
        case .code: return .purple
        case .json: return .indigo
        case .address: return .red
        case .image: return .pink
        case .file: return .gray
        }
    }
}

struct FavoriteClipCard: View {
    @EnvironmentObject var manager: ClipboardManager
    let item: ClipboardItem
    @Binding var selectedItem: ClipboardItem?
    @Binding var editedContent: String
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 10))
                
                Spacer()
                
                CategoryBadge(category: item.category)
            }
            
            Text(item.displayContent)
                .font(.system(size: 11))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
        }
        .frame(width: 120, height: 60)
        .padding(8)
        .background(isHovered ? Color.accentColor.opacity(0.15) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            selectedItem = item
            editedContent = item.content
            manager.copyToClipboard(item)
        }
    }
}

struct ClipboardDetailView: View {
    @EnvironmentObject var manager: ClipboardManager
    let item: ClipboardItem
    @Binding var editedContent: String
    let onClose: () -> Void
    let onSave: () -> Void
    let onContentChange: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Item")
                    .font(.system(size: 14, weight: .semibold))
                
                Spacer()
                
                CategoryBadge(category: item.category)
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content editor
            TextEditor(text: $editedContent)
                .font(.system(size: 12))
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: editedContent) {
                    onContentChange()
                }
            
            Divider()
            
            // Actions
            HStack(spacing: 12) {
                Button("Copy") {
                    // Copy the current edited content to clipboard
                    let tempItem = ClipboardItem(content: editedContent, type: item.type)
                    manager.copyToClipboard(tempItem)
                }
                .buttonStyle(.borderedProminent)
                
                Button("Save") {
                    onSave()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(action: {
                    manager.toggleFavorite(item)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: item.isFavorite ? "star.fill" : "star")
                        Text(item.isFavorite ? "Favorited" : "Favorite")
                    }
                    .font(.system(size: 11))
                    .foregroundColor(item.isFavorite ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        }
    }
}

/// Export history view
struct ExportHistoryView: View {
    let manager: ClipboardManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedFormat: ExportFormat = .json
    @State private var includeOnlyFavorites = false
    @State private var isExporting = false
    @State private var exportError: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Export Clipboard History")
                .font(.headline)
            
            Form {
                Picker("Format:", selection: $selectedFormat) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.radioGroup)
                
                Toggle("Include only favorites", isOn: $includeOnlyFavorites)
                
                Text("\(manager.items.count) items will be exported")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let error = exportError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                
                Spacer()
                
                Button("Export...") {
                    exportHistory()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExporting)
            }
        }
        .padding()
        .frame(width: 350, height: 250)
    }
    
    private func exportHistory() {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Clipboard History"
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "clipboard_history.\(selectedFormat.fileExtension)"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                isExporting = true
                exportError = nil
                
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        try manager.exportHistory(
                            to: url,
                            format: selectedFormat,
                            includeOnlyFavorites: includeOnlyFavorites
                        )
                        
                        DispatchQueue.main.async {
                            isExporting = false
                            dismiss()
                        }
                    } catch {
                        DispatchQueue.main.async {
                            isExporting = false
                            exportError = "Export failed: \(error.localizedDescription)"
                        }
                    }
                }
            }
        }
    }
}
