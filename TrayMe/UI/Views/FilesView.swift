//
//  FilesView.swift
//  TrayMe
//

import SwiftUI
import UniformTypeIdentifiers
import Quartz
import QuickLookThumbnailing

struct FilesView: View {
    @EnvironmentObject var manager: FilesManager
    @State private var hoveredFile: UUID?
    @State private var isDragging = false
    @State private var selectedFile: FileItem?
    @State private var quickLookTrigger = false
    @FocusState private var isFileAreaFocused: Bool
    @FocusState private var isSearchFocused: Bool
    @State private var eventMonitor: Any?
    @State private var panelHideObserver: NSObjectProtocol?
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search files...", text: $manager.searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onKeyPress(.space) {
                        // Let space through only when search field is focused
                        return isSearchFocused ? .ignored : .handled
                    }
                
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
            
            // Drop zone or file list
            if manager.files.isEmpty {
                // Empty state with drop zone
                DropZoneView(isDragging: $isDragging)
            } else {
                // Files grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 12)
                    ], spacing: 12) {
                        ForEach(manager.filteredFiles) { file in
                            FileCard(
                                file: file,
                                isHovered: hoveredFile == file.id,
                                isSelected: selectedFile?.id == file.id
                            )
                            .onHover { hovering in
                                hoveredFile = hovering ? file.id : nil
                            }
                            .onTapGesture {
                                selectedFile = file
                                isSearchFocused = false
                                isFileAreaFocused = true
                            }
                        }
                    }
                    .padding()
                }
                .focusable()
                .focused($isFileAreaFocused)
                .onTapGesture {
                    // Clicking empty area clears selection and removes search focus
                    selectedFile = nil
                    isSearchFocused = false
                    isFileAreaFocused = true
                }
                .background(
                    DropZoneView(isDragging: $isDragging)
                        .opacity(isDragging ? 0.5 : 0)
                )
                .background(QuickLookPreview(url: selectedFile?.resolvedURL(), isPresented: $quickLookTrigger))
            }
            
            // Footer
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(manager.files.count) files")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        HStack(spacing: 2) {
                            Image(systemName: "doc.badge.plus")
                                .font(.system(size: 8))
                            Text("Stored")
                                .font(.system(size: 7))
                        }
                        .foregroundColor(.green)
                        
                        HStack(spacing: 2) {
                            Image(systemName: "link")
                                .font(.system(size: 8))
                            Text("Ref")
                                .font(.system(size: 7))
                        }
                        .foregroundColor(.blue)
                    }
                    .font(.system(size: 8))
                }
                
                Spacer()
                
                Toggle("Copy files", isOn: $manager.shouldCopyFiles)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    .help("Copy files to app storage instead of just referencing them")
                
                if !manager.files.isEmpty {
                    Button("Clear All") {
                        manager.clearAll()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        }
        .onAppear {
            setupEventMonitor()
        }
        .onDisappear {
            removeEventMonitor()
        }
        .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
            handleDrop(providers: providers)
            return true
        }
    }
    
    // MARK: - Helper Functions
    
    func setupEventMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Handle space bar - toggle Quick Look
            if event.keyCode == 49 && selectedFile != nil && !isSearchFocused {
                if let panel = QLPreviewPanel.shared(), panel.isVisible {
                    panel.orderOut(nil)
                } else {
                    quickLookTrigger = true
                }
                return nil // Event handled, don't pass it on
            }
            
            // Handle arrow keys for navigation when Quick Look is shown
            if let panel = QLPreviewPanel.shared(), panel.isVisible {
                let currentIndex = manager.filteredFiles.firstIndex { $0.id == selectedFile?.id } ?? 0
                
                switch event.keyCode {
                case 123, 126: // Left arrow or Up arrow - previous file
                    if currentIndex > 0 {
                        selectedFile = manager.filteredFiles[currentIndex - 1]
                        quickLookTrigger = true
                        return nil
                    }
                case 124, 125: // Right arrow or Down arrow - next file
                    if currentIndex < manager.filteredFiles.count - 1 {
                        selectedFile = manager.filteredFiles[currentIndex + 1]
                        quickLookTrigger = true
                        return nil
                    }
                default:
                    break
                }
            }
            
            return event // Pass other events through
        }
        
        // Listen for panel hide notification to close Quick Look
        panelHideObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MainPanelWillHide"),
            object: nil,
            queue: .main
        ) { _ in
            if let panel = QLPreviewPanel.shared(), panel.isVisible {
                panel.orderOut(nil)
            }
        }
    }
    
    func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        
        if let observer = panelHideObserver {
            NotificationCenter.default.removeObserver(observer)
            panelHideObserver = nil
        }
    }
    
    func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        manager.addFile(url: url)
                    }
                }
            }
        }
    }
}

struct DropZoneView: View {
    @Binding var isDragging: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 48))
                .foregroundColor(isDragging ? .accentColor : .secondary)
            
            Text("Drop files here")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isDragging ? .accentColor : .primary)
            
            Text("Files will be temporarily stored for easy access")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isDragging ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [8])
                )
                .padding(20)
        )
    }
}

struct FileCard: View {
    @EnvironmentObject var manager: FilesManager
    let file: FileItem
    let isHovered: Bool
    let isSelected: Bool
    @State private var thumbnail: NSImage?
    @State private var isCopiedFile: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            // File thumbnail/icon with badge
            ZStack(alignment: .topTrailing) {
                if let thumb = thumbnail {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else if let cachedThumb = file.thumbnail {
                    // Use cached thumbnail from FileItem
                    Image(nsImage: cachedThumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else if let icon = file.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                } else {
                    Image(systemName: "doc")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                }
                
                // Storage type badge
                if isCopiedFile {
                    HStack(spacing: 2) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 8))
                        Text("Stored")
                            .font(.system(size: 7, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .offset(x: -2, y: 2)
                } else {
                    HStack(spacing: 2) {
                        Image(systemName: "link")
                            .font(.system(size: 8))
                        Text("Ref")
                            .font(.system(size: 7, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .offset(x: -2, y: 2)
                }
            }
            .frame(width: 80, height: 60)
            
            // File name
            Text(file.name)
                .font(.system(size: 11))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            // File size
            Text(file.formattedSize)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            
            // Actions (visible on hover)
            if isHovered {
                HStack(spacing: 4) {
                    Button(action: {
                        manager.openFile(file)
                    }) {
                        Image(systemName: "arrow.up.forward.square")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .help("Open")
                    
                    Button(action: {
                        copyFullImageToClipboard()
                    }) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .help("Copy Image")
                    
                    Button(action: {
                        manager.revealInFinder(file)
                    }) {
                        Image(systemName: "folder")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .help("Show in Finder")
                    
                    Button(action: {
                        manager.removeFile(file)
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Delete")
                }
                .padding(.top, 4)
            }
        }
        .frame(width: 100, height: 140)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : isHovered ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .onDrag {
            NSItemProvider(object: file.url as NSURL)
        }
        .onAppear {
            // Compute isCopiedFile once on appear
            if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let storageFolder = appSupport.appendingPathComponent("TrayMe/StoredFiles")
                let fileStandardized = file.url.standardizedFileURL.path
                let storageStandardized = storageFolder.standardizedFileURL.path
                isCopiedFile = fileStandardized.hasPrefix(storageStandardized)
            }
            loadThumbnail()
        }
        .contextMenu {
            Text(isCopiedFile ? "📦 Stored File" : "🔗 Referenced File")
                .font(.system(size: 11, weight: .semibold))
            
            Divider()
            
            Button("Open") {
                manager.openFile(file)
            }
            
            Button("Show in Finder") {
                manager.revealInFinder(file)
            }
            
            if thumbnail != nil {
                Button("Copy Image") {
                    copyFullImageToClipboard()
                }
            }
            
            Divider()
            
            Button("Delete", role: .destructive) {
                manager.removeFile(file)
            }
        }
    }
    
    func loadThumbnail() {
        // First check if we already have a cached thumbnail
        if file.thumbnail != nil {
            return // Already have persisted thumbnail
        }
        
        Task {
            // Use resolvedURL() to handle security-scoped bookmarks for referenced files
            guard let resolvedURL = file.resolvedURL() else {
                print("⚠️ Cannot resolve file URL for thumbnail: \(file.name)")
                return
            }
            let thumb = await FileThumbnailGenerator.generateThumbnailAsync(for: resolvedURL, size: CGSize(width: 160, height: 120))
            await MainActor.run {
                if let thumb = thumb {
                    self.thumbnail = thumb
                    // Save thumbnail to file item for persistence
                    manager.updateFileThumbnail(file.id, thumbnail: thumb)
                }
            }
        }
    }
    
    func copyFullImageToClipboard() {
        // Only copy if the file is an image
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp"]
        guard imageExtensions.contains(file.url.pathExtension.lowercased()) else {
            print("⚠️ Cannot copy non-image file to clipboard")
            return
        }
        
        // Use resolvedURL() to handle security-scoped bookmarks for referenced files
        guard let resolvedURL = file.resolvedURL() else {
            print("❌ Cannot resolve file URL for: \(file.name)")
            return
        }
        
        // Start accessing security-scoped resource for referenced files
        let isAccessing = resolvedURL.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                resolvedURL.stopAccessingSecurityScopedResource()
            }
        }
        
        // Load the full-resolution image
        if let fullImage = NSImage(contentsOf: resolvedURL) {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([fullImage])
        } else {
            print("⚠️ Failed to load image from file")
        }
    }
}

// MARK: - Quick Look Preview

struct QuickLookPreview: NSViewRepresentable {
    let url: URL?
    @Binding var isPresented: Bool
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if isPresented, let url = url {
            DispatchQueue.main.async {
                context.coordinator.showPreview(for: url, in: nsView.window)
                // Reset trigger
                isPresented = false
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
        var previewURL: URL?
        var isAccessingSecurityScope = false
        
        func showPreview(for url: URL, in window: NSWindow?) {
            // Clean up previous URL's security scope if it's different
            if let previousURL = previewURL, previousURL != url, isAccessingSecurityScope {
                previousURL.stopAccessingSecurityScopedResource()
                isAccessingSecurityScope = false
            }
            
            // Update to new URL
            self.previewURL = url
            
            // Start accessing security-scoped resource for new URL
            isAccessingSecurityScope = url.startAccessingSecurityScopedResource()
            
            guard let panel = QLPreviewPanel.shared() else { return }
            panel.dataSource = self
            panel.delegate = self
            
            if panel.isVisible {
                panel.reloadData()
            } else {
                panel.makeKeyAndOrderFront(nil)
            }
        }
        
        deinit {
            // Clean up security-scoped access
            if isAccessingSecurityScope, let url = previewURL {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // MARK: - QLPreviewPanelDataSource
        
        func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
            return previewURL != nil ? 1 : 0
        }
        
        func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
            return previewURL as QLPreviewItem?
        }
        
        // MARK: - QLPreviewPanelDelegate
        
        func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
            return false
        }
        
        func previewPanel(_ panel: QLPreviewPanel!, sourceFrameOnScreenFor item: QLPreviewItem!) -> NSRect {
            return .zero
        }
    }
}

// MARK: - Thumbnail Generator

class FileThumbnailGenerator {
    // Async version without semaphore - avoids priority inversion
    static func generateThumbnailAsync(for url: URL, size: CGSize) async -> NSImage? {
        // Start accessing security-scoped resource for referenced files
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // Try QuickLook thumbnail first
        if let quickLookThumbnail = await generateQuickLookThumbnailAsync(for: url, size: size) {
            return quickLookThumbnail
        }
        
        // For images, generate directly
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp"]
        if imageExtensions.contains(url.pathExtension.lowercased()) {
            return generateImageThumbnail(for: url, size: size)
        }
        
        // Return workspace icon as fallback
        return NSWorkspace.shared.icon(forFile: url.path)
    }
    
    static func generateQuickLookThumbnailAsync(for url: URL, size: CGSize) async -> NSImage? {
        if #available(macOS 10.15, *) {
            let scale = NSScreen.main?.backingScaleFactor ?? 2.0
            let request = QLThumbnailGenerator.Request(
                fileAt: url,
                size: size,
                scale: scale,
                representationTypes: .thumbnail
            )
            
            return await withCheckedContinuation { continuation in
                QLThumbnailGenerator.shared.generateRepresentations(for: request) { representation, type, error in
                    continuation.resume(returning: representation?.nsImage)
                }
            }
        }
        return nil
    }
    
    // DEPRECATED: Use generateThumbnailAsync instead
    // This synchronous version uses DispatchSemaphore which can cause priority inversion
    @available(*, deprecated, message: "Use generateThumbnailAsync instead to avoid thread blocking")
    static func generateThumbnail(for url: URL, size: CGSize) -> NSImage? {
        // Return workspace icon as fallback - avoid expensive operations
        return NSWorkspace.shared.icon(forFile: url.path)
    }
    
    // DEPRECATED: Use generateQuickLookThumbnailAsync instead
    @available(*, deprecated, message: "Use generateQuickLookThumbnailAsync instead to avoid priority inversion")
    static func generateQuickLookThumbnail(for url: URL, size: CGSize) -> NSImage? {
        return nil // Deprecated - use async version
    }
    
    static func generateImageThumbnail(for url: URL, size: CGSize) -> NSImage? {
        guard let image = NSImage(contentsOf: url) else {
            return nil
        }
        
        let thumbnail = NSImage(size: size)
        thumbnail.lockFocus()
        
        let imageRect = NSRect(origin: .zero, size: image.size)
        let thumbnailRect = NSRect(origin: .zero, size: size)
        
        image.draw(in: thumbnailRect,
                   from: imageRect,
                   operation: .copy,
                   fraction: 1.0)
        
        thumbnail.unlockFocus()
        return thumbnail
    }
}
