//
//  ClipboardView.swift
//  TrayMe
//

import SwiftUI

struct ClipboardView: View {
    @EnvironmentObject var manager: ClipboardManager
    @State private var hoveredItem: UUID?
    
    var body: some View {
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
                                FavoriteClipCard(item: item)
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
                            isHovered: hoveredItem == item.id
                        )
                        .onHover { hovering in
                            hoveredItem = hovering ? item.id : nil
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
    }
}

struct ClipboardItemRow: View {
    @EnvironmentObject var manager: ClipboardManager
    let item: ClipboardItem
    let isHovered: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            Image(systemName: iconForType(item.type))
                .foregroundColor(colorForType(item.type))
                .frame(width: 20)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayContent)
                    .font(.system(size: 13))
                    .lineLimit(2)
                
                Text(item.timeAgo)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
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
                .fill(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .onTapGesture {
            manager.copyToClipboard(item)
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
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .onTapGesture {
            manager.copyToClipboard(item)
        }
    }
}
