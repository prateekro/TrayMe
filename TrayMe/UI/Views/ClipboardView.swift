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
    @StateObject private var securityManager = SecurityManager.shared
    let item: ClipboardItem
    let isHovered: Bool
    let isSelected: Bool
    
    private var category: ClipboardCategory {
        manager.getCategory(for: item)
    }
    
    private var isSensitive: Bool {
        manager.isSensitive(item)
    }
    
    private var shouldBlur: Bool {
        isSensitive && securityManager.sensitiveItemsLocked
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Type icon with category
            ZStack {
                Image(systemName: category.icon)
                    .foregroundColor(colorForCategory(category))
                    .frame(width: 20)
                
                // Sensitive indicator
                if isSensitive {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.orange)
                        .offset(x: 10, y: -8)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Group {
                    if shouldBlur {
                        Text(String(repeating: "•", count: min(item.displayContent.count, 20)))
                            .font(.system(size: 13))
                    } else {
                        Text(item.displayContent)
                            .font(.system(size: 13))
                            .lineLimit(2)
                    }
                }
                .blur(radius: shouldBlur ? 4 : 0)
                
                HStack(spacing: 4) {
                    Text(item.timeAgo)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    // Category badge
                    Text(category.displayName)
                        .font(.system(size: 8))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(colorForCategory(category))
                        .cornerRadius(3)
                }
            }
            
            Spacer()
            
            // Actions (visible on hover)
            if isHovered {
                HStack(spacing: 8) {
                    // Unlock button for sensitive content
                    if isSensitive && shouldBlur {
                        Button(action: {
                            Task {
                                await securityManager.authenticateForSensitiveContent()
                            }
                        }) {
                            Image(systemName: "lock.open")
                                .foregroundColor(.orange)
                        }
                        .buttonStyle(.plain)
                        .help("Unlock to view")
                    }
                    
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
        case .code: return .purple
        case .url: return .blue
        case .email: return .cyan
        case .address: return .green
        case .phone: return .teal
        case .credential: return .red
        case .json: return .orange
        case .markdown: return .pink
        case .plainText: return .gray
        }
    }
    
    func iconForType(_ type: ClipboardItem.ClipboardType) -> String {
        switch type {
        case .text: return "doc.text"
        case .url: return "link"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .image: return "photo"
        }
    }
    
    func colorForType(_ type: ClipboardItem.ClipboardType) -> Color {
        switch type {
        case .text: return .blue
        case .url: return .green
        case .code: return .purple
        case .image: return .orange
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
