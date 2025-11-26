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
    @Environment(\.controlActiveState) private var controlActiveState
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
    @State private var fileStatusRefreshTrigger = UUID() // Trigger to force FileCard re-render
    
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
            if manager.isLoading {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text("Loading files...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if manager.files.isEmpty {
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
                                isWindowFocused: controlActiveState == .key,
                                showCopiedFeedback: $showCopiedFeedback,
                                refreshTrigger: fileStatusRefreshTrigger
                            )
                            .onHover { hovering in
                                hoveredFile = hovering ? file.id : nil
                            }
                            .onTapGesture {
                                selectedFile = file
                                isSearchFocused = false
                                isFileAreaFocused = true
                                
                                // If Quick Look is already open, update preview to this file
                                if let panel = QLPreviewPanel.shared(), panel.isVisible {
                                    quickLookTrigger = true
                                }
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
                .background(QuickLookPreview(file: selectedFile, isPresented: $quickLookTrigger))
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
                        
                        Divider()
                        
                        // Refresh references
                        Button(action: {
                            refreshMissingFileStates()
                        }) {
                            Label("Refresh File Status", systemImage: "arrow.clockwise")
                        }
                        .keyboardShortcut(.init("r"), modifiers: [.command])
                        .help("Re-check if reference files still exist")
                        
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
        .onChange(of: controlActiveState) { oldValue, newValue in
            // Clear selection when window loses focus
            if newValue != .key {
                selectedFile = nil
            }
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
    
    func refreshMissingFileStates() {
        print("🔄 Refreshing file status for all reference files...")
        // Trigger re-check by changing the UUID (forces FileCard to re-run onAppear)
        fileStatusRefreshTrigger = UUID()
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
    let isWindowFocused: Bool
    @State private var isCopiedFile: Bool = false
    @State private var imageThumbnail: NSImage? = nil
    @State private var isFileMissing: Bool = false
    @Binding var showCopiedFeedback: Bool
    let refreshTrigger: UUID // When this changes, re-check file status
    
    // Computed property for instant icon - no async needed!
    private var displayIcon: NSImage {
        // For images, show actual thumbnail if loaded
        if let thumb = imageThumbnail {
            return thumb
        }
        
        if let resolvedURL = file.resolvedURL() {
            // Native workspace icon - instant and perfect
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
                ZStack {
                    Image(nsImage: displayIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .opacity(isFileMissing ? 0.3 : 1.0)
                    
                    // Missing file indicator
                    if isFileMissing {
                        VStack(spacing: 2) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.orange)
                            Text("Missing")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(.orange)
                        }
                    }
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
                    .background(isFileMissing ? Color.red : Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .offset(x: -2, y: 2)
                    .help(isFileMissing ? "Original file not found - may have been moved or deleted" : "Reference only - original file remains in its location")
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
                .fill(
                    isSelected && isWindowFocused 
                        ? Color.accentColor.opacity(0.2) 
                        : isHovered 
                            ? Color.accentColor.opacity(0.1) 
                            : Color(NSColor.controlBackgroundColor)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .onDrag {
            NSItemProvider(object: file.url as NSURL)
        }
        .onAppear {
            checkFileStatus()
            loadImageThumbnail()
        }
        .onChange(of: refreshTrigger) {
            // Re-check file status when refresh is triggered
            checkFileStatus()
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
            
            // Only show "Copy Image" for image files
            let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp"]
            if imageExtensions.contains(file.fileType.lowercased()) {
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
    
    func checkFileStatus() {
        // Compute isCopiedFile once on appear
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let storageFolder = appSupport.appendingPathComponent("TrayMe/StoredFiles")
            let fileStandardized = file.url.standardizedFileURL.path
            let storageStandardized = storageFolder.standardizedFileURL.path
            isCopiedFile = fileStandardized.hasPrefix(storageStandardized)
        }
        
        // Check if reference file still exists (only for reference files)
        if !isCopiedFile {
            print("🔍 Checking if reference file exists: \(file.name)")
            Task(priority: .utility) {
                let exists = file.fileExists()
                print("🔍 File existence result for \(file.name): \(exists)")
                await MainActor.run {
                    isFileMissing = !exists
                    print("🔍 Set isFileMissing = \(isFileMissing) for \(file.name)")
                }
            }
        }
    }
    
    func loadImageThumbnail() {
        // Only generate thumbnails for images - everything else uses workspace icons
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp"]
        guard imageExtensions.contains(file.fileType.lowercased()) else {
            return // Non-images get workspace icons (instant)
        }
        
        guard let resolvedURL = file.resolvedURL() else { return }
        
        // Check cache FIRST (super fast - just file read, no JSON parsing!)
        if let cached = FilesManager.getCachedThumbnail(for: resolvedURL) {
            self.imageThumbnail = cached
            return
        }
        
        // Generate thumbnail in background if not cached
        Task(priority: .utility) {
            // Start security-scoped access
            let isAccessing = resolvedURL.startAccessingSecurityScopedResource()
            defer {
                if isAccessing {
                    resolvedURL.stopAccessingSecurityScopedResource()
                }
            }
            
            // Load and resize image
            guard let image = NSImage(contentsOf: resolvedURL) else { return }
            
            let targetSize = CGSize(width: 160, height: 120)
            let thumbnail = NSImage(size: targetSize)
            thumbnail.lockFocus()
            
            let imageRect = NSRect(origin: .zero, size: image.size)
            let thumbnailRect = NSRect(origin: .zero, size: targetSize)
            
            image.draw(in: thumbnailRect, from: imageRect, operation: .copy, fraction: 1.0)
            thumbnail.unlockFocus()
            
            // Cache to disk for next time (PNG is small and fast)
            FilesManager.cacheThumbnail(thumbnail, for: resolvedURL)
            
            await MainActor.run {
                self.imageThumbnail = thumbnail
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
    let file: FileItem?
    @Binding var isPresented: Bool
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if isPresented, let file = file {
            print("🔍 QuickLook triggered for: \(file.name)")
            
            DispatchQueue.main.async {
                context.coordinator.showPreview(for: file, in: nsView.window)
                // Reset trigger
                isPresented = false
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
        var previewFile: FileItem?
        var resolvedURL: URL?
        var isAccessingSecurityScope = false
        
        func showPreview(for file: FileItem, in window: NSWindow?) {
            print("🔍 Coordinator.showPreview called for: \(file.name)")
            
            // Clean up previous file's security scope
            if isAccessingSecurityScope, let url = resolvedURL {
                url.stopAccessingSecurityScopedResource()
                isAccessingSecurityScope = false
            }
            
            // Update to new file
            self.previewFile = file
            
            // Resolve URL from bookmark if available
            guard let url = resolveURLForQuickLook(file: file) else {
                print("❌ Failed to resolve URL for file")
                return
            }
            
            self.resolvedURL = url
            print("🔍 Resolved URL: \(url.path)")
            print("🔍 File exists: \(FileManager.default.fileExists(atPath: url.path))")
            
            // Start accessing security-scoped resource
            isAccessingSecurityScope = url.startAccessingSecurityScopedResource()
            print("🔍 Security scope access: \(isAccessingSecurityScope)")
            
            guard let panel = QLPreviewPanel.shared() else {
                print("❌ QLPreviewPanel.shared() returned nil")
                return
            }
            
            print("🔍 Setting up panel")
            panel.dataSource = self
            panel.delegate = self
            
            if panel.isVisible {
                print("🔍 Panel already visible, reloading")
                panel.reloadData()
            } else {
                print("🔍 Showing panel")
                panel.makeKeyAndOrderFront(nil)
            }
            
            print("🔍 Panel isVisible: \(panel.isVisible)")
        }
        
        // Resolve URL with proper security scope for QuickLook
        private func resolveURLForQuickLook(file: FileItem) -> URL? {
            print("🔍 resolveURLForQuickLook for: \(file.name)")
            print("🔍 Has bookmark data: \(file.bookmarkData != nil)")
            if let bookmarkData = file.bookmarkData {
                print("🔍 Bookmark data size: \(bookmarkData.count) bytes")
            }
            
            // If we have bookmark data, resolve it
            if let bookmarkData = file.bookmarkData {
                do {
                    var isStale = false
                    let url = try URL(
                        resolvingBookmarkData: bookmarkData,
                        options: .withSecurityScope,
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale
                    )
                    print("🔍 Resolved from bookmark: \(url.path)")
                    print("🔍 Bookmark is stale: \(isStale)")
                    return url
                } catch {
                    print("⚠️ Bookmark resolution failed: \(error.localizedDescription)")
                    // Fall through to try original URL
                }
            } else {
                print("⚠️ No bookmark data available")
            }
            
            // For stored files or if bookmark fails, use original URL
            print("🔍 Using original URL: \(file.url.path)")
            return file.url
        }
        
        deinit {
            // Clean up security-scoped access
            if isAccessingSecurityScope, let url = resolvedURL {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // MARK: - QLPreviewPanelDataSource
        
        func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
            return resolvedURL != nil ? 1 : 0
        }
        
        func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
            return resolvedURL as QLPreviewItem?
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
