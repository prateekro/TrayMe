//
//  FilesView.swift
//  TrayMe
//

import SwiftUI
import UniformTypeIdentifiers
import Quartz

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
    @State private var fileStatusRefreshTrigger = UUID()
    
    // Keyboard key codes for better readability
    private enum KeyCode {
        static let space: UInt16 = 49
        static let leftArrow: UInt16 = 123
        static let rightArrow: UInt16 = 124
        static let downArrow: UInt16 = 125
        static let upArrow: UInt16 = 126
    }
    
    // Supported image file extensions
    fileprivate static let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "heic", "webp"]
    
    enum ClearAction {
        case allReferences
        case allStored
        case everything
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            SearchBarView(text: $manager.searchText, placeholder: "Search files…")
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)
            
            // Drop zone or file list
            if manager.isLoading {
                VStack(spacing: 14) {
                    ProgressView()
                        .controlSize(.small)
                    
                    Text("Loading files…")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if manager.files.isEmpty {
                DropZoneView(isDragging: $isDragging)
            } else if manager.filteredFiles.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.quaternary)
                    
                    Text("No files found")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    Text("Try a different search term")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Files grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 10)
                    ], spacing: 10) {
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
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    hoveredFile = hovering ? file.id : nil
                                }
                            }
                            .onTapGesture {
                                selectedFile = file
                                isSearchFocused = false
                                isFileAreaFocused = true
                                
                                if let panel = QLPreviewPanel.shared(), panel.isVisible {
                                    quickLookTrigger = true
                                }
                            }
                        }
                    }
                    .padding(12)
                }
                .focusable()
                .focused($isFileAreaFocused)
                .focusEffectDisabled()
                .onTapGesture {
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
            HStack(spacing: 8) {
                // File count with progress ring
                FilesCountBadge(current: manager.files.count, max: manager.maxFiles)
                
                Spacer()
                
                if selectedFile != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "space")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(Color.primary.opacity(0.08))
                            )
                        Text("Quick Look")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundStyle(.tertiary)
                }
                
                Toggle(isOn: $manager.shouldCopyFiles) {
                    HStack(spacing: 4) {
                        Image(systemName: manager.shouldCopyFiles ? "doc.badge.plus" : "link")
                            .font(.system(size: 10))
                        Text(manager.shouldCopyFiles ? "Copy" : "Reference")
                            .font(.system(size: 10, weight: .medium))
                    }
                }
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
                .help("Copy files to app storage instead of just referencing them")
                
                if !manager.files.isEmpty {
                    Menu {
                        Button(action: {
                            manager.openStorageFolder()
                        }) {
                            Label("Open Storage Folder", systemImage: "folder")
                        }
                        .keyboardShortcut(.init("o"), modifiers: [.command, .shift])
                        
                        Menu {
                            ForEach([25, 50, 75, 100], id: \.self) { limit in
                                Button(action: {
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
                        
                        Button(action: {
                            refreshMissingFileStates()
                        }) {
                            Label("Refresh File Status", systemImage: "arrow.clockwise")
                        }
                        .keyboardShortcut(.init("r"), modifiers: [.command])
                        .help("Re-check if reference files still exist")
                        
                        Divider()
                        
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
                            Label("Delete…", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            
            // Copy feedback overlay
            if showCopiedFeedback {
                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Image copied")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                    .padding(.bottom, 50)
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
            Button("Open Manage Menu") { }
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
            if event.keyCode == KeyCode.space && selectedFile != nil && !isSearchFocused {
                if let panel = QLPreviewPanel.shared(), panel.isVisible {
                    panel.orderOut(nil)
                } else {
                    quickLookTrigger = true
                }
                return nil
            }
            
            if let panel = QLPreviewPanel.shared(), panel.isVisible {
                let currentIndex = manager.filteredFiles.firstIndex { $0.id == selectedFile?.id } ?? 0
                
                switch event.keyCode {
                case KeyCode.leftArrow, KeyCode.upArrow:
                    if currentIndex > 0 {
                        selectedFile = manager.filteredFiles[currentIndex - 1]
                        quickLookTrigger = true
                        return nil
                    }
                case KeyCode.rightArrow, KeyCode.downArrow:
                    if currentIndex < manager.filteredFiles.count - 1 {
                        selectedFile = manager.filteredFiles[currentIndex + 1]
                        quickLookTrigger = true
                        return nil
                    }
                default:
                    break
                }
            }
            
            return event
        }
        
        panelHideObserver = NotificationCenter.default.addObserver(
            forName: .mainPanelWillHide,
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
        fileStatusRefreshTrigger = UUID()
    }
    
    func handleDrop(providers: [NSItemProvider]) {
        let dropCount = providers.count
        let currentCount = manager.files.count
        let availableSlots = manager.maxFiles - currentCount
        
        if dropCount > availableSlots {
            dropLimitMessage = "You're trying to add \(dropCount) file\(dropCount == 1 ? "" : "s"), but only \(availableSlots) slot\(availableSlots == 1 ? "" : "s") available (limit: \(manager.maxFiles)).\n\nPlease remove some files first or increase the limit in the Manage menu."
            showDropLimitAlert = true
            return
        }
        
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

// MARK: - Files Count Badge

struct FilesCountBadge: View {
    let current: Int
    let max: Int
    
    private var progress: Double {
        guard max > 0 else { return 0 }
        return Double(current) / Double(max)
    }
    
    private var color: Color {
        if progress >= 1.0 { return .orange }
        if progress >= 0.8 { return .yellow }
        return .accentColor
    }
    
    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 2)
                    .frame(width: 14, height: 14)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 14, height: 14)
                    .rotationEffect(.degrees(-90))
            }
            
            Text("\(current)/\(max)")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}

struct DropZoneView: View {
    @Binding var isDragging: Bool
    
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isDragging ? Color.accentColor.opacity(0.1) : Color.primary.opacity(0.03))
                    .frame(width: 72, height: 72)
                
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(isDragging ? Color.accentColor : .secondary)
                    .symbolEffect(.bounce, value: isDragging)
            }
            
            Text("Drop files here")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(isDragging ? Color.accentColor : .primary)
            
            Text("Files will be temporarily stored for easy access")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isDragging ? Color.accentColor : Color.primary.opacity(0.08),
                    style: StrokeStyle(lineWidth: isDragging ? 2 : 1.5, dash: [8, 4])
                )
                .padding(16)
        )
        .animation(.easeInOut(duration: 0.2), value: isDragging)
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
    let refreshTrigger: UUID
    
    private var displayIcon: NSImage {
        if let thumb = imageThumbnail {
            return thumb
        }
        
        if let resolvedURL = file.resolvedURL() {
            return NSWorkspace.shared.icon(forFile: resolvedURL.path)
        }
        if let icon = file.icon {
            return icon
        }
        if let contentType = UTType(filenameExtension: file.fileType) {
            return NSWorkspace.shared.icon(for: contentType)
        }
        return NSWorkspace.shared.icon(for: .data)
    }
    
    var body: some View {
        VStack(spacing: 6) {
            // File thumbnail/icon with badge
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Image(nsImage: displayIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 76, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                        )
                        .opacity(isFileMissing ? 0.3 : 1.0)
                    
                    if isFileMissing {
                        VStack(spacing: 2) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.orange)
                            Text("Missing")
                                .font(.system(size: 7, weight: .bold, design: .rounded))
                                .foregroundStyle(.orange)
                        }
                    }
                }
                
                // Storage type badge
                StorageTypeBadge(isCopied: isCopiedFile, isMissing: isFileMissing)
                    .offset(x: 2, y: -2)
            }
            .frame(width: 76, height: 56)
            
            // File name
            Text(file.name)
                .font(.system(size: 10.5, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .help(file.name)
            
            // File size
            Text(file.formattedSize)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.tertiary)
            
            // Actions (visible on hover)
            if isHovered {
                HStack(spacing: 4) {
                    CircleActionButton(systemName: "arrow.up.forward.square", tint: .accentColor) {
                        manager.openFile(file)
                    }
                    
                    CircleActionButton(systemName: "photo.on.rectangle", tint: .blue) {
                        copyFullImageToClipboard()
                    }
                    
                    CircleActionButton(systemName: "folder", tint: .secondary) {
                        manager.revealInFinder(file)
                    }
                    
                    CircleActionButton(systemName: "trash", tint: isCopiedFile ? .red : .orange) {
                        manager.removeFile(file)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
        .frame(width: 100, height: isHovered ? 145 : 115)
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    isSelected && isWindowFocused
                        ? Color.accentColor.opacity(0.12)
                        : isHovered
                            ? Color.primary.opacity(0.04)
                            : Color.clear
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor.opacity(0.35) : Color.clear,
                    lineWidth: 1.5
                )
        )
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onDrag {
            NSItemProvider(object: file.url as NSURL)
        }
        .onAppear {
            checkFileStatus()
            loadImageThumbnail()
        }
        .onChange(of: refreshTrigger) {
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
            
            if FilesView.imageExtensions.contains(file.fileType.lowercased()) {
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
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let storageFolder = appSupport.appendingPathComponent("TrayMe/StoredFiles")
            let fileStandardized = file.url.standardizedFileURL.path
            let storageStandardized = storageFolder.standardizedFileURL.path
            isCopiedFile = fileStandardized.hasPrefix(storageStandardized)
        }
        
        if !isCopiedFile {
            Task(priority: .utility) {
                let exists = file.fileExists()
                await MainActor.run {
                    isFileMissing = !exists
                }
            }
        }
    }
    
    func loadImageThumbnail() {
        guard FilesView.imageExtensions.contains(file.fileType.lowercased()) else {
            return
        }
        
        guard let resolvedURL = file.resolvedURL() else { return }
        
        if let cached = FilesManager.getCachedThumbnail(for: resolvedURL) {
            self.imageThumbnail = cached
            return
        }
        
        Task(priority: .utility) {
            let isAccessing = resolvedURL.startAccessingSecurityScopedResource()
            defer {
                if isAccessing {
                    resolvedURL.stopAccessingSecurityScopedResource()
                }
            }
            
            guard let image = NSImage(contentsOf: resolvedURL) else { return }
            
            let targetSize = CGSize(width: 160, height: 120)
            let thumbnail = NSImage(size: targetSize)
            
            if let bitmapRep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(targetSize.width),
                pixelsHigh: Int(targetSize.height),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ) {
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
                
                let imageRect = NSRect(origin: .zero, size: image.size)
                let thumbnailRect = NSRect(origin: .zero, size: targetSize)
                image.draw(in: thumbnailRect, from: imageRect, operation: .copy, fraction: 1.0)
                
                NSGraphicsContext.restoreGraphicsState()
                thumbnail.addRepresentation(bitmapRep)
            }
            
            FilesManager.cacheThumbnail(thumbnail, for: resolvedURL)
            
            await MainActor.run {
                self.imageThumbnail = thumbnail
            }
        }
    }
    
    func copyFullImageToClipboard() {
        guard FilesView.imageExtensions.contains(file.url.pathExtension.lowercased()) else {
            return
        }
        
        guard let resolvedURL = file.resolvedURL() else {
            return
        }
        
        let isAccessing = resolvedURL.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                resolvedURL.stopAccessingSecurityScopedResource()
            }
        }
        
        if let fullImage = NSImage(contentsOf: resolvedURL) {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([fullImage])
            
            withAnimation(.easeInOut(duration: 0.3)) {
                showCopiedFeedback = true
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                withAnimation(.easeInOut(duration: 0.3)) {
                    showCopiedFeedback = false
                }
            }
        }
    }
}

// MARK: - Storage Type Badge

struct StorageTypeBadge: View {
    let isCopied: Bool
    let isMissing: Bool
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: isCopied ? "doc.badge.plus" : "link")
                .font(.system(size: 7, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 4)
        .padding(.vertical, 2.5)
        .background(
            Capsule()
                .fill(badgeColor)
        )
        .shadow(color: badgeColor.opacity(0.3), radius: 2, y: 1)
    }
    
    private var badgeColor: Color {
        if isMissing { return .red }
        return isCopied ? .green : .orange
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
            DispatchQueue.main.async {
                context.coordinator.showPreview(for: file, in: nsView.window)
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
            if isAccessingSecurityScope, let url = resolvedURL {
                url.stopAccessingSecurityScopedResource()
                isAccessingSecurityScope = false
            }
            
            self.previewFile = file
            
            guard let url = resolveURLForQuickLook(file: file) else {
                return
            }
            
            self.resolvedURL = url
            
            isAccessingSecurityScope = url.startAccessingSecurityScopedResource()
            
            guard let panel = QLPreviewPanel.shared() else {
                return
            }
            
            panel.dataSource = self
            panel.delegate = self
            
            if panel.isVisible {
                panel.reloadData()
            } else {
                panel.makeKeyAndOrderFront(nil)
            }
        }
        
        private func resolveURLForQuickLook(file: FileItem) -> URL? {
            if let bookmarkData = file.bookmarkData {
                do {
                    var isStale = false
                    let url = try URL(
                        resolvingBookmarkData: bookmarkData,
                        options: .withSecurityScope,
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale
                    )
                    return url
                } catch {
                    // Fall through
                }
            }
            
            return file.url
        }
        
        deinit {
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
