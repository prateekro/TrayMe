//
//  FilesManager.swift
//  TrayMe
//

import SwiftUI
import AppKit
import Combine

class FilesManager: ObservableObject {
    @Published var files: [FileItem] = []
    @Published var searchText: String = ""
    @AppStorage("shouldCopyFiles") var shouldCopyFiles: Bool = false
    @AppStorage("maxFiles") private var storedMaxFiles: Int = 50
    
    // Computed property to enforce max limit of 100
    var maxFiles: Int {
        get { min(storedMaxFiles, 100) }
        set { storedMaxFiles = min(newValue, 100) }
    }
    
    private var thumbnailCache: [UUID: NSImage] = [:]
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
        loadFromDisk()
    }

    func addFile(url: URL) {
        // Check if file already exists
        if files.contains(where: { $0.url == url }) {
            return
        }
        
        // Copy file if setting is enabled, otherwise just reference
        let finalURL: URL
        if shouldCopyFiles {
            if let copiedURL = copyFileToStorage(url) {
                finalURL = copiedURL
            } else {
                // Copy failed - show error and use reference instead
                print("⚠️ Failed to copy file \(url.lastPathComponent), using reference instead")
                finalURL = url
            }
        } else {
            finalURL = url
        }
        
        let newFile = FileItem(url: finalURL)
        
        DispatchQueue.main.async {
            self.files.insert(newFile, at: 0)
            
            // Enforce limit (for single file additions via other methods)
            if self.files.count > self.maxFiles {
                // Remove oldest files beyond limit
                let toRemove = self.files.suffix(self.files.count - self.maxFiles)
                for file in toRemove {
                    if let storageFolder = self.storageFolderURL, 
                       self.isFileInStorage(file.url, storageFolder: storageFolder) {
                        try? FileManager.default.removeItem(at: file.url)
                    }
                }
                self.files = Array(self.files.prefix(self.maxFiles))
            }
            
            self.saveToDisk()
            
            // Populate metadata asynchronously to avoid blocking
            // Only for single file additions (e.g., from clipboard)
            Task(priority: .utility) {
                await self.populateFileMetadata(fileID: newFile.id)
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
            print("❌ Storage folder unavailable, cannot copy file")
            return nil
        }
        
        let fileName = sourceURL.lastPathComponent
        let destinationURL = storageFolder.appendingPathComponent(fileName)
        
        // If file exists, add number suffix
        var finalURL = destinationURL
        var counter = 1
        while FileManager.default.fileExists(atPath: finalURL.path) {
            let nameWithoutExt = sourceURL.deletingPathExtension().lastPathComponent
            let ext = sourceURL.pathExtension
            let newName = "\(nameWithoutExt) \(counter).\(ext)"
            finalURL = storageFolder.appendingPathComponent(newName)
            counter += 1
        }
        
        do {
            try FileManager.default.copyItem(at: sourceURL, to: finalURL)
            return finalURL
        } catch {
            print("❌ Failed to copy file: \(error.localizedDescription)")
            return nil
        }
    }
    
    func addFiles(urls: [URL]) {
        // Filter out duplicates and files that already exist
        let newURLs = urls.filter { url in
            !files.contains(where: { $0.url == url })
        }
        
        guard !newURLs.isEmpty else { return }
        
        // Process files in batch
        var newFiles: [FileItem] = []
        
        for url in newURLs {
            // Copy file if setting is enabled, otherwise just reference
            let finalURL: URL
            if shouldCopyFiles {
                if let copiedURL = copyFileToStorage(url) {
                    finalURL = copiedURL
                } else {
                    print("⚠️ Failed to copy file \(url.lastPathComponent), using reference instead")
                    finalURL = url
                }
            } else {
                finalURL = url
            }
            
            newFiles.append(FileItem(url: finalURL))
        }
        
        // Add all new files at once and save only once
        DispatchQueue.main.async {
            self.files.insert(contentsOf: newFiles, at: 0)
            
            // No truncation here - validation happens before drop in FilesView
            // This ensures we don't lose existing files
            
            self.saveToDisk()
            
            // DON'T populate metadata on add - do it lazily when files are viewed
            // This prevents the app from freezing when adding many files
        }
    }
    
    func removeFile(_ file: FileItem) {
        // If file is in our storage folder, delete it
        if let storageFolder = storageFolderURL, isFileInStorage(file.url, storageFolder: storageFolder) {
            do {
                try FileManager.default.removeItem(at: file.url)
            } catch {
                print("⚠️ Failed to delete stored file: \(error.localizedDescription)")
            }
        }
        
        files.removeAll { $0.id == file.id }
        thumbnailCache.removeValue(forKey: file.id)
        saveToDisk()
    }
    
    func clearAll() {
        // Delete all copied files
        if let storageFolder = storageFolderURL {
            for file in files where isFileInStorage(file.url, storageFolder: storageFolder) {
                do {
                    try FileManager.default.removeItem(at: file.url)
                } catch {
                    print("⚠️ Failed to delete stored file: \(error.localizedDescription)")
                }
            }
        }
        
        files.removeAll()
        thumbnailCache.removeAll()
        saveToDisk()
    }
    
    func clearAllReferences() {
        // Remove only referenced files (not stored in app)
        guard let storageFolder = storageFolderURL else {
            files.removeAll()
            thumbnailCache.removeAll()
            saveToDisk()
            return
        }
        
        let referencedFiles = files.filter { !isFileInStorage($0.url, storageFolder: storageFolder) }
        for file in referencedFiles {
            thumbnailCache.removeValue(forKey: file.id)
        }
        
        files.removeAll { !isFileInStorage($0.url, storageFolder: storageFolder) }
        saveToDisk()
    }
    
    func clearAllStored() {
        // Delete all stored files but keep references
        guard let storageFolder = storageFolderURL else { return }
        
        let storedFiles = files.filter { isFileInStorage($0.url, storageFolder: storageFolder) }
        
        for file in storedFiles {
            do {
                try FileManager.default.removeItem(at: file.url)
                thumbnailCache.removeValue(forKey: file.id)
            } catch {
                print("⚠️ Failed to delete stored file: \(error.localizedDescription)")
            }
        }
        
        files.removeAll { isFileInStorage($0.url, storageFolder: storageFolder) }
        saveToDisk()
    }
    
    private func isFileInStorage(_ fileURL: URL, storageFolder: URL) -> Bool {
        let fileStandardized = fileURL.standardizedFileURL.path
        let storageStandardized = storageFolder.standardizedFileURL.path
        return fileStandardized.hasPrefix(storageStandardized)
    }
    
    func openFile(_ file: FileItem) {
        guard let resolvedURL = file.resolvedURL() else {
            print("❌ Cannot open file - URL resolution failed: \(file.name)")
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
            print("❌ Cannot reveal file - URL resolution failed: \(file.name)")
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
    
    func getCachedThumbnail(for fileID: UUID) -> NSImage? {
        return thumbnailCache[fileID]
    }
    
    func cacheThumbnail(_ image: NSImage, for fileID: UUID) {
        thumbnailCache[fileID] = image
    }
    
    func updateFileThumbnail(_ fileID: UUID, thumbnail: NSImage) {
        if let index = files.firstIndex(where: { $0.id == fileID }) {
            var updatedFile = files[index]
            updatedFile.thumbnailData = thumbnail.tiffRepresentation
            files[index] = updatedFile
            cacheThumbnail(thumbnail, for: fileID)
            saveToDisk()
        }
    }
    
    func openStorageFolder() {
        guard let storageFolder = storageFolderURL else {
            print("❌ Storage folder not available")
            return
        }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: storageFolder.path)
    }
    
    func refreshAllThumbnails() {
        // Clear all cached thumbnails to force regeneration
        thumbnailCache.removeAll()
        
        // Clear thumbnail data from file items
        for index in files.indices {
            files[index].thumbnailData = nil
        }
        
        saveToDisk()
        
        // Trigger view refresh by publishing changes
        objectWillChange.send()
    }
    
    // MARK: - Persistence
    
    private var saveURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("TrayMe", isDirectory: true)
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        return appFolder.appendingPathComponent("files.json")
    }
    
    func saveToDisk() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(files) {
            try? data.write(to: saveURL)
        }
    }
    
    func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: saveURL.path) else { return }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        if let data = try? Data(contentsOf: saveURL),
           let decoded = try? decoder.decode([FileItem].self, from: data) {
            // Filter out files that no longer exist
            self.files = decoded.filter { FileManager.default.fileExists(atPath: $0.url.path) }
        }
    }
}
