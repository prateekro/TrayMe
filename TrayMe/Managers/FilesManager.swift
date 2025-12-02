//
//  FilesManager.swift
//  TrayMe
//

import SwiftUI
import AppKit
import Combine
import CryptoKit
import os.log

/// Private logger for FilesManager
private let logger = Logger(subsystem: "com.trayme.TrayMe", category: "FilesManager")

class FilesManager: ObservableObject {
    @Published var files: [FileItem] = []
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @AppStorage("shouldCopyFiles") var shouldCopyFiles: Bool = false
    @AppStorage("maxFiles") private var storedMaxFiles: Int = 50
    
    // Debounce save operations to avoid excessive disk writes
    private var saveWorkItem: DispatchWorkItem?
    private let saveDebounceInterval: TimeInterval = 0.5 // Wait 500ms before saving
    
    // Computed property to enforce max limit of 100
    var maxFiles: Int {
        get { min(storedMaxFiles, 100) }
        set { storedMaxFiles = min(newValue, 100) }
    }
    
    // Fast thumbnail cache directory - uses Caches (cleaned by system when needed)
    private static let thumbnailCacheDir: URL? = {
        guard let appSupport = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            print("❌ Could not access Caches directory")
            return nil
        }
        let cacheDir = appSupport.appendingPathComponent("TrayMe/Thumbnails")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        return cacheDir
    }()
    
    // Fast bookmark cache directory - separate from JSON for speed
    private static let bookmarkCacheDir: URL? = {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("❌ Could not access Application Support directory")
            return nil
        }
        let cacheDir = appSupport.appendingPathComponent("TrayMe/Bookmarks")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        return cacheDir
    }()
    
    // Generate cache key from file ID (fast, unique)
    static func bookmarkCacheKey(for fileID: UUID) -> String {
        return fileID.uuidString + ".bookmark"
    }
    
    // Save bookmark to separate file (much faster than JSON)
    static func saveBookmark(_ data: Data, for fileID: UUID) {
        guard let cacheDir = bookmarkCacheDir else { return }
        let cacheFile = cacheDir.appendingPathComponent(bookmarkCacheKey(for: fileID))
        try? data.write(to: cacheFile, options: .atomic)
    }
    
    // Load bookmark from cache
    static func loadBookmark(for fileID: UUID) -> Data? {
        guard let cacheDir = bookmarkCacheDir else { return nil }
        let cacheFile = cacheDir.appendingPathComponent(bookmarkCacheKey(for: fileID))
        return try? Data(contentsOf: cacheFile)
    }
    
    // Delete bookmark from cache
    static func deleteBookmark(for fileID: UUID) {
        guard let cacheDir = bookmarkCacheDir else { return }
        let cacheFile = cacheDir.appendingPathComponent(bookmarkCacheKey(for: fileID))
        try? FileManager.default.removeItem(at: cacheFile)
    }
    
    // Generate cache key from file URL (hash for short, filesystem-safe names)
    static func thumbnailCacheKey(for fileURL: URL) -> String {
        let path = fileURL.standardizedFileURL.path
        let hash = SHA256.hash(data: Data(path.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined().prefix(32) + ".png"
    }
    
    // Get cached thumbnail (super fast - just file read)
    static func getCachedThumbnail(for fileURL: URL) -> NSImage? {
        guard let cacheDir = thumbnailCacheDir else { return nil }
        let cacheFile = cacheDir.appendingPathComponent(thumbnailCacheKey(for: fileURL))
        return NSImage(contentsOf: cacheFile)
    }
    
    // Save thumbnail to cache (PNG is fast and small)
    static func cacheThumbnail(_ image: NSImage, for fileURL: URL) {
        guard let cacheDir = thumbnailCacheDir else { return }
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return
        }
        
        let cacheFile = cacheDir.appendingPathComponent(thumbnailCacheKey(for: fileURL))
        try? pngData.write(to: cacheFile, options: .atomic)
    }
    
    private var storageFolderURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("❌ Failed to locate Application Support directory")
            return nil
        }
        let appFolder = appSupport.appendingPathComponent("TrayMe", isDirectory: true)
        let filesFolder = appFolder.appendingPathComponent("StoredFiles", isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(at: filesFolder, withIntermediateDirectories: true)
            return filesFolder
        } catch {
            print("❌ Failed to create storage folder: \(error.localizedDescription)")
            return nil
        }
    }
    
    init() {
        let startTime = CFAbsoluteTimeGetCurrent()
        logger.info("FilesManager init started")
        
        // Load files asynchronously in background to avoid blocking app launch
        // JSON parsing is fast (~10KB), but we do it off main thread for best performance
        loadFromDisk()
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        logger.debug("FilesManager init took \(String(format: "%.3f", timeElapsed))s")
    }
    
    private func loadFromDisk() {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        guard FileManager.default.fileExists(atPath: saveURL.path) else {
            logger.info("No saved files to load")
            return 
        }
        
        // Load in background to avoid blocking app launch
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            do {
                let data = try Data(contentsOf: self.saveURL)
                let decoded = try decoder.decode([FileItem].self, from: data)
                
                let loadTime = CFAbsoluteTimeGetCurrent() - startTime
                
                DispatchQueue.main.async {
                    self.files = decoded
                    logger.debug("Loaded \(decoded.count) files in \(String(format: "%.3f", loadTime))s")
                }
            } catch {
                logger.error("Failed to load/decode files: \(error.localizedDescription)")
            }
        }
        
        logger.debug("Starting background load...")
    }

    func addFile(url: URL) {
        // Check if file already exists
        if files.contains(where: { $0.url == url }) {
            logger.debug("Skipping duplicate file: \(url.lastPathComponent)")
            return
        }
        
        // Copy file if setting is enabled, otherwise just reference
        let finalURL: URL
        if shouldCopyFiles {
            if let copiedURL = copyFileToStorage(url) {
                finalURL = copiedURL
            } else {
                // Copy failed - show error and use reference instead
                logger.warning("Failed to copy file \(url.lastPathComponent), using reference instead")
                finalURL = url
            }
        } else {
            finalURL = url
        }
        
        let newFile = FileItem(url: finalURL)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.files.insert(newFile, at: 0)
            
            // Enforce limit (for single file additions via other methods)
            if self.files.count > self.maxFiles {
                // Remove oldest files beyond limit
                let toRemove = self.files.suffix(self.files.count - self.maxFiles)
                for file in toRemove {
                    if let storageFolder = self.storageFolderURL, 
                       self.isFileInStorage(file.url, storageFolder: storageFolder) {
                        do {
                            try FileManager.default.removeItem(at: file.url)
                        } catch {
                            logger.error("Failed to remove old file: \(error.localizedDescription)")
                        }
                    }
                }
                self.files = Array(self.files.prefix(self.maxFiles))
            }
            
            self.saveToDisk()
            
            // Populate metadata asynchronously to avoid blocking
            // Only for single file additions (e.g., from clipboard)
            Task(priority: .utility) { [weak self] in
                await self?.populateFileMetadata(fileID: newFile.id)
            }
        }
    }
    
    private func populateFileMetadata(fileID: UUID) async {
        // Safely capture the file first
        guard let index = files.firstIndex(where: { $0.id == fileID }) else { return }
        var file = files[index]
        
        // Run metadata population in background
        await Task.detached(priority: .utility) {
            file.populateMetadata()
            
            // Update back on main actor
            await MainActor.run {
                // Re-check index in case array was modified
                if let currentIndex = self.files.firstIndex(where: { $0.id == fileID }) {
                    self.files[currentIndex] = file
                }
            }
        }.value
    }
    
    private func copyFileToStorage(_ sourceURL: URL) -> URL? {
        guard let storageFolder = storageFolderURL else {
            logger.error("Storage folder unavailable, cannot copy file")
            return nil
        }
        
        let fileName = sourceURL.lastPathComponent
        let destinationURL = storageFolder.appendingPathComponent(fileName)
        
        // Prevent infinite loop - limit retries to 1000
        let maxRetries = 1000
        var finalURL = destinationURL
        var counter = 1
        
        while FileManager.default.fileExists(atPath: finalURL.path) && counter < maxRetries {
            let nameWithoutExt = sourceURL.deletingPathExtension().lastPathComponent
            let ext = sourceURL.pathExtension
            let newName = "\(nameWithoutExt) \(counter).\(ext)"
            finalURL = storageFolder.appendingPathComponent(newName)
            counter += 1
        }
        
        // Safety check - if we hit max retries, abort
        if counter >= maxRetries {
            logger.error("Max retries reached (\(maxRetries)) when trying to copy \(fileName)")
            return nil
        }
        
        do {
            try FileManager.default.copyItem(at: sourceURL, to: finalURL)
            logger.debug("File copied to storage: \(fileName)")
            return finalURL
        } catch {
            logger.error("Failed to copy file: \(error.localizedDescription)")
            return nil
        }
    }
    
    func addFiles(urls: [URL]) {
        #if DEBUG
        print("📥 addFiles called with \(urls.count) URLs")
        print("📥 Copy mode: \(shouldCopyFiles ? "COPY" : "REFERENCE")")
        #endif
        
        // Smart duplicate filtering:
        // - Block if same file already exists in same mode (reference or stored)
        // - Allow if switching modes (reference -> copy or copy -> reference)
        let newURLs = urls.filter { url in
            let standardizedURL = url.standardizedFileURL
            
            // Check if we already have this file in the SAME mode
            let hasDuplicate = files.contains { existingFile in
                let existingStandardized = existingFile.url.standardizedFileURL
                
                // If storage folder is unavailable, treat all files as duplicates to be safe
                guard let storageFolder = storageFolderURL else { return true }
                
                let isExistingStored = isFileInStorage(existingFile.url, storageFolder: storageFolder)
                let willBeStored = shouldCopyFiles
                
                // Same file, same mode = duplicate
                if existingStandardized.path == standardizedURL.path && isExistingStored == willBeStored {
                    return true
                }
                
                // If modes match, check by name (handles stored copies from same source)
                if isExistingStored == willBeStored && existingFile.name == url.lastPathComponent {
                    return true
                }
                
                return false
            }
            
            #if DEBUG
            if hasDuplicate {
                print("⏭️ Skipping duplicate: \(url.lastPathComponent) (already exists in same mode)")
            } else {
                print("✅ Will add: \(url.lastPathComponent)")
            }
            #endif
            return !hasDuplicate
        }
        
        #if DEBUG
        print("📥 After filtering: \(newURLs.count) new files to add")
        #endif
        
        guard !newURLs.isEmpty else {
            #if DEBUG
            print("⚠️ No new files to add (all were duplicates)")
            #endif
            return
        }
        
        // Process files in batch
        var newFiles: [FileItem] = []
        
        for url in newURLs {
            // Copy file if setting is enabled, otherwise just reference
            let finalURL: URL
            if shouldCopyFiles {
                if let copiedURL = copyFileToStorage(url) {
                    finalURL = copiedURL
                } else {
                    logger.warning("Failed to copy file \(url.lastPathComponent), using reference instead")
                    finalURL = url
                }
            } else {
                finalURL = url
            }
            
            let newFile = FileItem(url: finalURL)
            newFiles.append(newFile)
        }
        
        // Add all new files at once
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.files.insert(contentsOf: newFiles, at: 0)
            self.saveToDisk()
        }
        
        // Create bookmarks in background (non-blocking)
        if !shouldCopyFiles {
            DispatchQueue.global(qos: .utility).async {
                for var file in newFiles {
                    file.populateMetadata()
                    
                    if let bookmarkData = file.bookmarkData {
                        FilesManager.saveBookmark(bookmarkData, for: file.id)
                        logger.debug("Saved bookmark to cache for: \(file.name)")
                    }
                }
            }
        }
    }
    
    func removeFile(_ file: FileItem) {
        // If file is in our storage folder, delete it
        if let storageFolder = storageFolderURL, isFileInStorage(file.url, storageFolder: storageFolder) {
            do {
                try FileManager.default.removeItem(at: file.url)
            } catch {
                logger.warning("Failed to delete stored file: \(error.localizedDescription)")
            }
        }
        
        // Delete bookmark cache if exists
        FilesManager.deleteBookmark(for: file.id)
        
        files.removeAll { $0.id == file.id }
        saveToDisk()
    }
    
    func clearAll() {
        // Delete all copied files
        if let storageFolder = storageFolderURL {
            for file in files where isFileInStorage(file.url, storageFolder: storageFolder) {
                do {
                    try FileManager.default.removeItem(at: file.url)
                } catch {
                    logger.warning("Failed to delete stored file: \(error.localizedDescription)")
                }
            }
        }
        
        // Delete all bookmark caches
        for file in files {
            FilesManager.deleteBookmark(for: file.id)
        }
        
        files.removeAll()
        saveToDisk()
        logger.info("Cleared all files")
    }
    
    func clearAllReferences() {
        // Remove only referenced files (not stored in app)
        guard let storageFolder = storageFolderURL else {
            // Delete all bookmark caches
            for file in files {
                FilesManager.deleteBookmark(for: file.id)
            }
            files.removeAll()
            saveToDisk()
            return
        }
        
        // Delete bookmarks for reference files
        let referencedFiles = files.filter { !isFileInStorage($0.url, storageFolder: storageFolder) }
        for file in referencedFiles {
            FilesManager.deleteBookmark(for: file.id)
        }
        
        files.removeAll { !isFileInStorage($0.url, storageFolder: storageFolder) }
        saveToDisk()
        logger.info("Cleared all reference files")
    }
    
    func clearAllStored() {
        // Delete all stored files but keep references
        guard let storageFolder = storageFolderURL else { return }
        
        let storedFiles = files.filter { isFileInStorage($0.url, storageFolder: storageFolder) }
        
        for file in storedFiles {
            do {
                try FileManager.default.removeItem(at: file.url)
            } catch {
                logger.warning("Failed to delete stored file: \(error.localizedDescription)")
            }
        }
        
        files.removeAll { isFileInStorage($0.url, storageFolder: storageFolder) }
        saveToDisk()
        logger.info("Cleared all stored files")
    }
    
    private func isFileInStorage(_ fileURL: URL, storageFolder: URL) -> Bool {
        let fileStandardized = fileURL.standardizedFileURL.path
        let storageStandardized = storageFolder.standardizedFileURL.path
        return fileStandardized.hasPrefix(storageStandardized)
    }
    
    func openFile(_ file: FileItem) {
        guard let resolvedURL = file.resolvedURL() else {
            logger.error("Cannot open file - URL resolution failed: \(file.name)")
            return
        }
        
        // Start accessing security-scoped resource for referenced files
        let isAccessing = resolvedURL.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                resolvedURL.stopAccessingSecurityScopedResource()
            }
        }
        
        NSWorkspace.shared.open(resolvedURL)
    }
    
    func revealInFinder(_ file: FileItem) {
        guard let resolvedURL = file.resolvedURL() else {
            logger.error("Cannot reveal file - URL resolution failed: \(file.name)")
            return
        }
        
        // Start accessing security-scoped resource for referenced files
        let isAccessing = resolvedURL.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                resolvedURL.stopAccessingSecurityScopedResource()
            }
        }
        
        NSWorkspace.shared.activateFileViewerSelecting([resolvedURL])
    }
    
    var filteredFiles: [FileItem] {
        if searchText.isEmpty {
            return files
        }
        return files.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    func getFilesForDragging(_ file: FileItem) -> [URL] {
        return [file.url]
    }
    
    func openStorageFolder() {
        guard let storageFolder = storageFolderURL else {
            logger.error("Storage folder not available")
            return
        }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: storageFolder.path)
    }
    
    // MARK: - Persistence
    
    private var saveURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("TrayMe", isDirectory: true)
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        return appFolder.appendingPathComponent("files.json")
    }
    
    func saveToDisk() {
        // Cancel any pending save
        saveWorkItem?.cancel()
        
        // Create new debounced save task
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [] // No pretty printing for speed
            
            do {
                let data = try encoder.encode(self.files)
                try data.write(to: self.saveURL, options: .atomic)
                logger.debug("Files saved successfully (\(self.files.count) files)")
            } catch {
                logger.error("Failed to save files: \(error.localizedDescription)")
            }
        }
        
        saveWorkItem = workItem
        
        // Execute after debounce interval (batch multiple saves)
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + saveDebounceInterval, execute: workItem)
    }
    
    deinit {
        // Save immediately on deinit to ensure no data loss
        saveWorkItem?.cancel()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(files) {
            try? data.write(to: saveURL, options: .atomic)
        }
    }
}
