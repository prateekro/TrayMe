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
                SearchBarView(text: $manager.searchText, placeholder: "Search clipboard…")
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                
                // Favorites section
                if !manager.favorites.isEmpty && manager.searchText.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Favorites", systemImage: "star.fill")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(manager.favorites) { item in
                                    FavoriteClipCard(item: item, selectedItem: $selectedItem, editedContent: $editedContent)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .frame(height: 80)
                    }
                    .padding(.bottom, 8)
                    
                    Rectangle()
                        .fill(Color.primary.opacity(0.06))
                        .frame(height: 1)
                        .padding(.horizontal, 12)
                }
                
                // Clipboard history
                if manager.filteredItems.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: manager.searchText.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(.quaternary)
                        
                        Text(manager.searchText.isEmpty ? "Clipboard is empty" : "No results")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        if !manager.searchText.isEmpty {
                            Text("Try a different search term")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(manager.filteredItems) { item in
                                ClipboardItemRow(
                                    item: item,
                                    isHovered: hoveredItem == item.id,
                                    isSelected: selectedItem?.id == item.id
                                )
                                .contentShape(Rectangle())
                                .onHover { hovering in
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        hoveredItem = hovering ? item.id : nil
                                    }
                                }
                                .onTapGesture {
                                    selectItem(item)
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                }
                
                // Footer
                HStack {
                    Text("\(manager.items.count) items")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                    
                    Spacer()
                    
                    if !manager.items.isEmpty {
                        Button {
                            manager.clearHistory()
                        } label: {
                            Text("Clear")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            
            // Detail/Edit panel
            if let item = selectedItem {
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 1)
                
                ClipboardDetailView(
                    item: item,
                    editedContent: $editedContent,
                    onClose: {
                        saveWorkItem?.cancel()
                        if let item = selectedItem {
                            manager.updateItemContent(item, newContent: editedContent)
                        }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedItem = nil
                        }
                    },
                    onSave: {
                        saveWorkItem?.cancel()
                        manager.updateItemContent(item, newContent: editedContent)
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedItem = nil
                        }
                    },
                    onContentChange: {
                        saveWorkItem?.cancel()
                        let workItem = DispatchWorkItem { [weak manager] in
                            manager?.updateItemContent(item, newContent: editedContent)
                        }
                        saveWorkItem = workItem
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
                    }
                )
                .frame(width: 300)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }
    
    func selectItem(_ item: ClipboardItem) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedItem = item
        }
        editedContent = item.content
        manager.copyToClipboard(item)
    }
}

// MARK: - Reusable Search Bar

struct SearchBarView: View {
    @Binding var text: String
    var placeholder: String = "Search…"
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isFocused)
            
            if !text.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        text = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(isFocused ? 0.06 : 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isFocused ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

struct ClipboardItemRow: View {
    @EnvironmentObject var manager: ClipboardManager
    let item: ClipboardItem
    let isHovered: Bool
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Type icon or image thumbnail
            if item.type == .image, let image = item.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                    )
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(colorForType(item.type).opacity(0.12))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: iconForType(item.type))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(colorForType(item.type))
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayContent)
                    .font(.system(size: 12.5))
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                
                Text(item.timeAgo)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            
            Spacer(minLength: 4)
            
            // Actions (visible on hover)
            if isHovered {
                HStack(spacing: 6) {
                    CircleActionButton(
                        systemName: item.isFavorite ? "star.fill" : "star",
                        tint: item.isFavorite ? .yellow : .secondary
                    ) {
                        manager.toggleFavorite(item)
                    }
                    
                    CircleActionButton(systemName: "doc.on.doc", tint: .accentColor) {
                        manager.copyToClipboard(item)
                    }
                    
                    CircleActionButton(systemName: "trash", tint: .red) {
                        manager.deleteItem(item)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    isSelected
                    ? Color.accentColor.opacity(0.15)
                    : (isHovered ? Color.primary.opacity(0.04) : Color.clear)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
    
    func iconForType(_ type: ClipboardItem.ClipboardType) -> String {
        switch type {
        case .text: return "doc.text.fill"
        case .url: return "link"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .image: return "photo.fill"
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

// MARK: - Reusable Circle Action Button

struct CircleActionButton: View {
    let systemName: String
    var tint: Color = .secondary
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(tint.opacity(isPressed ? 0.15 : 0.08))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = h
            }
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
                    .foregroundStyle(.yellow)
                    .font(.system(size: 9))
                Spacer()
            }
            
            // Show image thumbnail or text content
            if item.type == .image, let image = item.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            } else {
                Text(item.displayContent)
                    .font(.system(size: 11))
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Spacer()
        }
        .frame(width: 120, height: 60)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHovered ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isHovered ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.06), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
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
    
    @State private var showingImageEditor = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(item.type == .image ? "Preview" : "Edit")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                
                Spacer()
                
                if item.type == .image {
                    Button("Edit Image") {
                        showingImageEditor = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 1)
            
            // Content editor or image preview
            if item.type == .image, let image = item.image {
                ScrollView {
                    VStack(spacing: 12) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                            .padding(16)
                        
                        Text(item.content)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.tertiary)
                            .padding(.bottom, 8)
                    }
                }
            } else {
                TextEditor(text: $editedContent)
                    .font(.system(size: 12))
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scrollContentBackground(.hidden)
                    .onChange(of: editedContent) {
                        onContentChange()
                    }
            }
            
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 1)
            
            // Actions
            HStack(spacing: 10) {
                Button("Copy") {
                    manager.copyToClipboard(item)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                
                if item.type != .image {
                    Button("Save") {
                        onSave()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Spacer()
                
                Button {
                    manager.toggleFavorite(item)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: item.isFavorite ? "star.fill" : "star")
                        Text(item.isFavorite ? "Saved" : "Save")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(item.isFavorite ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
        }
        .onChange(of: showingImageEditor) { oldValue, newValue in
            if newValue && !oldValue {
                DispatchQueue.main.async {
                    ImageEditorWindowController.shared.openEditor(for: item)
                }
            } else if !newValue && oldValue {
                ImageEditorWindowController.shared.closeEditor()
            }
        }
    }
}

// MARK: - Image Editor Window Controller
class ImageEditorWindowController {
    static let shared = ImageEditorWindowController()
    
    private var editorWindow: NSWindow?
    private var windowCloseObserver: NSObjectProtocol?
    
    private init() {}
    
    func openEditor(for item: ClipboardItem) {
        if editorWindow != nil {
            closeEditor()
        }
        
        let editorView = ImageEditorView(item: item) { [weak self] in
            self?.closeEditor()
        }
        .environmentObject(ClipboardManager.shared)
        
        let hostingController = NSHostingController(rootView: editorView)
        
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Image Editor"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 800, height: 700))
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.minSize = NSSize(width: 600, height: 500)
        
        window.makeKeyAndOrderFront(nil)
        editorWindow = window
        
        windowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.cleanup()
        }
    }
    
    func closeEditor() {
        editorWindow?.close()
        cleanup()
    }
    
    private func cleanup() {
        if let observer = windowCloseObserver {
            NotificationCenter.default.removeObserver(observer)
            windowCloseObserver = nil
        }
        editorWindow = nil
    }
    
    deinit {
        cleanup()
    }
}
