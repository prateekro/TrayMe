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
    @State private var showClearAllConfirmation = false
    @State private var showCopiedFeedback = false
    @State private var clearAction: ClearAction?
    @State private var showDropLimitAlert = false
    @State private var dropLimitMessage = ""
    @State private var showLimitReductionAlert = false
    @State private var attemptedLimit = 25
    
    enum ClearAction {
        case allReferences
        case allStored
        case everything
    }
    
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
            } else if manager.filteredFiles.isEmpty {
                // Empty search results
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No files found")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text("Try a different search term")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                                isSelected: selectedFile?.id == file.id,
                                showCopiedFeedback: $showCopiedFeedback
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
                .focusEffectDisabled()
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
                    HStack(spacing: 4) {
                        Text("\(manager.files.count)/\(manager.maxFiles) files")
                            .font(.system(size: 11))
                            .foregroundColor(manager.files.count >= manager.maxFiles ? .orange : .secondary)
                        
                        if manager.files.count >= manager.maxFiles {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.orange)
                                .help("File limit reached - oldest files will be removed")
                        }
                    }
                    
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
                        .foregroundColor(.orange)
                    }
                    .font(.system(size: 8))
                }
                
                Spacer()
                
                if selectedFile != nil {
                    Text("Press Space for Quick Look")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.8))
                        .padding(.trailing, 8)
                }
                
                Toggle("Copy files", isOn: $manager.shouldCopyFiles)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    .help("Copy files to app storage instead of just referencing them")
                
                if !manager.files.isEmpty {
                    Menu {
                        // Open storage folder
                        Button(action: {
                            manager.openStorageFolder()
                        }) {
                            Label("Open Storage Folder", systemImage: "folder")
                        }
                        .keyboardShortcut(.init("o"), modifiers: [.command, .shift])
                        
                        // File limit selector
                        Menu {
                            ForEach([25, 50, 75, 100], id: \.self) { limit in
                                Button(action: {
                                    // Check if reducing limit would exceed current file count
                                    if limit < manager.files.count {
                                        attemptedLimit = limit
                                        showLimitReductionAlert = true
                                    } else {
                                        manager.maxFiles = limit
                                    }
                                }) {
                                    HStack {
                                        Text("\(limit) files")
                                        if manager.maxFiles == limit {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Label("File Limit (\(manager.maxFiles))", systemImage: "number.square")
                        }
                        
                        // Refresh thumbnails
                        Button(action: {
                            manager.refreshAllThumbnails()
                        }) {
                            Label("Refresh All Thumbnails", systemImage: "arrow.clockwise")
                        }
                        
                        Divider()
                        
                        // Delete submenu
                        Menu {
                            Button(action: {
                                clearAction = .allReferences
                                showClearAllConfirmation = true
                            }) {
                                Label {
                                    Text("All References")
                                        .foregroundColor(.orange)
                                } icon: {
                                    Image(systemName: "link")
                                        .foregroundColor(.orange)
                                }
                            }
                            .keyboardShortcut(.init("r"), modifiers: [.command, .shift])
                            
                            Button(action: {
                                clearAction = .allStored
                                showClearAllConfirmation = true
                            }) {
                                Label {
                                    Text("All Stored Files")
                                        .foregroundColor(.green)
                                } icon: {
                                    Image(systemName: "doc.badge.plus")
                                        .foregroundColor(.green)
                                }
                            }
                            .keyboardShortcut(.init("s"), modifiers: [.command, .shift])
                            
                            Divider()
                            
                            Button(action: {
                                clearAction = .everything
                                showClearAllConfirmation = true
                            }) {
                                Label {
                                    Text("Everything")
                                        .foregroundColor(.red)
                                } icon: {
                                    Image(systemName: "trash.fill")
                                        .foregroundColor(.red)
                                }
                            }
                            .keyboardShortcut(.delete, modifiers: [.command, .shift])
                        } label: {
                            Label("Delete...", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 11))
                            Text("Manage")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("File management options")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            
            // Copy feedback overlay
            if showCopiedFeedback {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Image copied to clipboard")
                                .font(.system(size: 11))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                        .shadow(radius: 4)
                        .padding()
                        Spacer()
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .alert(alertTitle, isPresented: $showClearAllConfirmation) {
            Button("Cancel", role: .cancel) { 
                clearAction = nil
            }
            Button(alertButtonText, role: .destructive) {
                performClearAction()
            }
        } message: {
            Text(alertMessage)
        }
        .alert("Cannot Add Files", isPresented: $showDropLimitAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(dropLimitMessage)
        }
        .alert("Cannot Reduce Limit", isPresented: $showLimitReductionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Open Manage Menu") {
                // User can manually delete files from the manage menu
            }
        } message: {
            Text("You have \(manager.files.count) files but want to set limit to \(attemptedLimit).\n\nPlease remove \(manager.files.count - attemptedLimit) file\(manager.files.count - attemptedLimit == 1 ? "" : "s") first using the Manage menu delete options.")
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
    
    // MARK: - Alert Properties
    
    private var alertTitle: String {
        switch clearAction {
        case .allReferences:
            return "Delete All References?"
        case .allStored:
            return "Delete All Stored Files?"
        case .everything:
            return "Delete Everything?"
        case .none:
            return ""
        }
    }
    
    private var alertMessage: String {
        switch clearAction {
        case .allReferences:
            return "This will remove all file references but keep stored files. Referenced files will remain in their original locations."
        case .allStored:
            return "This will permanently delete all files stored in the app. File references will remain. This action cannot be undone."
        case .everything:
            return "This will permanently delete all stored files and remove all references. This action cannot be undone."
        case .none:
            return ""
        }
    }
    
    private var alertButtonText: String {
        switch clearAction {
        case .allReferences:
            return "Delete References"
        case .allStored:
            return "Delete Files"
        case .everything:
            return "Delete Everything"
        case .none:
            return ""
        }
    }
    
    private func performClearAction() {
        guard let action = clearAction else { return }
        
        switch action {
        case .allReferences:
            manager.clearAllReferences()
        case .allStored:
            manager.clearAllStored()
        case .everything:
            manager.clearAll()
        }
        
        clearAction = nil
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
        let dropCount = providers.count
        let currentCount = manager.files.count
        let availableSlots = manager.maxFiles - currentCount
        
        // Check if drop would exceed limit
        if dropCount > availableSlots {
            dropLimitMessage = "You're trying to add \(dropCount) file\(dropCount == 1 ? "" : "s"), but only \(availableSlots) slot\(availableSlots == 1 ? "" : "s") available (limit: \(manager.maxFiles)).\n\nPlease remove some files first or increase the limit in the Manage menu."
            showDropLimitAlert = true
            return
        }
        
        // Collect all URLs first, then batch add
        var urlsToAdd: [URL] = []
        let group = DispatchGroup()
        
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                defer { group.leave() }
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urlsToAdd.append(url)
                }
            }
        }
        
        group.notify(queue: .main) {
            if !urlsToAdd.isEmpty {
                manager.addFiles(urls: urlsToAdd)
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
    @Binding var showCopiedFeedback: Bool
    
    // Computed property for instant icon - no async needed!
    private var displayIcon: NSImage {
        // Priority: cached thumbnail > generated thumbnail > workspace icon
        if let thumb = thumbnail {
            return thumb
        }
        if let cached = file.thumbnail {
            return cached
        }
        if let resolvedURL = file.resolvedURL() {
            // Instant workspace icon - no async needed
            return NSWorkspace.shared.icon(forFile: resolvedURL.path)
        }
        // Fallback to file type icon
        if let icon = file.icon {
            return icon
        }
        // Ultimate fallback - use modern API
        if let contentType = UTType(filenameExtension: file.fileType) {
            return NSWorkspace.shared.icon(for: contentType)
        }
        // Generic document icon if all else fails
        return NSWorkspace.shared.icon(for: .data)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // File thumbnail/icon with badge
            ZStack(alignment: .topTrailing) {
                Image(nsImage: displayIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
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
                    .help("File stored in app - will be deleted if you clear storage")
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
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .offset(x: -2, y: 2)
                    .help("Reference only - original file remains in its location")
                }
            }
            .frame(width: 80, height: 60)
            
            // File name with tooltip showing full name
            Text(file.name)
                .font(.system(size: 11))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .help(file.name)
            
            // File size
            Text(file.formattedSize)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .help("File size: \(file.formattedSize)")
            
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
                            .foregroundColor(isCopiedFile ? .red : .orange)
                    }
                    .buttonStyle(.plain)
                    .help(isCopiedFile ? "Delete file" : "Delete reference")
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
            // Only load enhanced thumbnails for images in background (optional enhancement)
            // Everything else already has instant workspace icon from displayIcon
            loadThumbnailIfImage()
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
            
            Button(isCopiedFile ? "Delete file" : "Delete reference", role: .destructive) {
                manager.removeFile(file)
            }
        }
    }
    
    func loadThumbnailIfImage() {
        // Only load enhanced thumbnails for images
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp"]
        guard imageExtensions.contains(file.fileType.lowercased()) else {
            return // Non-images already have great workspace icons
        }
        
        // First check if we already have a cached thumbnail
        if file.thumbnail != nil {
            return // Already have persisted thumbnail
        }
        
        // Check manager's cache before generating
        if let cached = manager.getCachedThumbnail(for: file.id) {
            self.thumbnail = cached
            return
        }
        
        Task(priority: .utility) {
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
            
            // Show success feedback
            showCopiedFeedback = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                showCopiedFeedback = false
            }
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

actor ThumbnailTaskCoordinator {
    private var activeTasks = 0
    private let maxConcurrentTasks = 8
    
    func acquireSlot() async {
        while activeTasks >= maxConcurrentTasks {
            try? await Task.sleep(for: .milliseconds(50))
        }
        activeTasks += 1
    }
    
    func releaseSlot() {
        activeTasks -= 1
    }
}

class FileThumbnailGenerator {
    private static let coordinator = ThumbnailTaskCoordinator()
    
    // Async version with concurrency limiting
    static func generateThumbnailAsync(for url: URL, size: CGSize) async -> NSImage? {
        // Acquire a slot (wait if too many tasks are active)
        await coordinator.acquireSlot()
        
        defer {
            Task {
                await coordinator.releaseSlot()
            }
        }
        
        // Start accessing security-scoped resource for referenced files
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // Strategy: Use fast workspace icon for most files, only generate thumbnails for images
        // This is what Finder does - workspace icons are instant and look great
        
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp"]
        
        // For images, try QuickLook thumbnail (fast for images)
        if imageExtensions.contains(url.pathExtension.lowercased()) {
            if let quickLookThumbnail = await generateQuickLookThumbnailAsync(for: url, size: size) {
                return quickLookThumbnail
            }
        }
        
        // For everything else (and image fallback), use workspace icon - instant!
        // This includes PDFs, videos, documents, etc. - their file type icons look professional
        return NSWorkspace.shared.icon(forFile: url.path)
    }
    
    static func generateQuickLookThumbnailAsync(for url: URL, size: CGSize) async -> NSImage? {
        if #available(macOS 10.15, *) {
            let scale = NSScreen.main?.backingScaleFactor ?? 2.0
            
            // Use icon mode for faster generation - perfect for file managers
            let request = QLThumbnailGenerator.Request(
                fileAt: url,
                size: size,
                scale: scale,
                representationTypes: .icon  // Changed from .thumbnail - much faster!
            )
            
            return await withCheckedContinuation { continuation in
                QLThumbnailGenerator.shared.generateRepresentations(for: request) { representation, type, error in
                    if let error = error {
                        print("⚠️ Thumbnail generation failed: \(error.localizedDescription)")
                    }
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
