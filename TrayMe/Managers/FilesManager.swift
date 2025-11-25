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
    @Published var shouldCopyFiles: Bool = false  // New setting
    
    private let maxFiles = 50
    private var thumbnailCache: [UUID: NSImage] = [:]
    private var storageFolderURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("TrayMe", isDirectory: true)
        let filesFolder = appFolder.appendingPathComponent("StoredFiles", isDirectory: true)
        try? FileManager.default.createDirectory(at: filesFolder, withIntermediateDirectories: true)
        return filesFolder
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
            finalURL = copyFileToStorage(url) ?? url
        } else {
            finalURL = url
        }
        
        var newFile = FileItem(url: finalURL)
        
        DispatchQueue.main.async {
            self.files.insert(newFile, at: 0)
            
            // Limit number of files
            if self.files.count > self.maxFiles {
                self.files = Array(self.files.prefix(self.maxFiles))
            }
            
            // Populate metadata asynchronously to avoid blocking
            Task {
                await self.populateFileMetadata(fileID: newFile.id)
            }
        }
    }
    
    private func populateFileMetadata(fileID: UUID) async {
        guard let index = files.firstIndex(where: { $0.id == fileID }) else { return }
        
        await Task.detached {
            var file = await self.files[index]
            file.populateMetadata()
            
            await MainActor.run {
                self.files[index] = file
                self.saveToDisk()
            }
        }.value
    }
    
    private func copyFileToStorage(_ sourceURL: URL) -> URL? {
        let fileName = sourceURL.lastPathComponent
        let destinationURL = storageFolderURL.appendingPathComponent(fileName)
        
        // If file exists, add number suffix
        var finalURL = destinationURL
        var counter = 1
        while FileManager.default.fileExists(atPath: finalURL.path) {
            let nameWithoutExt = sourceURL.deletingPathExtension().lastPathComponent
            let ext = sourceURL.pathExtension
            let newName = "\(nameWithoutExt) \(counter).\(ext)"
            finalURL = storageFolderURL.appendingPathComponent(newName)
            counter += 1
        }
        
        do {
            try FileManager.default.copyItem(at: sourceURL, to: finalURL)
            return finalURL
        } catch {
            print("Failed to copy file: \(error)")
            return nil
        }
    }
    
    func addFiles(urls: [URL]) {
        urls.forEach { addFile(url: $0) }
    }
    
    func removeFile(_ file: FileItem) {
        // If file is in our storage folder, delete it
        if file.url.path.starts(with: storageFolderURL.path) {
            try? FileManager.default.removeItem(at: file.url)
        }
        
        files.removeAll { $0.id == file.id }
        thumbnailCache.removeValue(forKey: file.id)
        saveToDisk()
    }
    
    func clearAll() {
        // Delete all copied files
        for file in files where file.url.path.starts(with: storageFolderURL.path) {
            try? FileManager.default.removeItem(at: file.url)
        }
        
        files.removeAll()
        thumbnailCache.removeAll()
        saveToDisk()
    }
    
    func openFile(_ file: FileItem) {
        NSWorkspace.shared.open(file.url)
    }
    
    func revealInFinder(_ file: FileItem) {
        NSWorkspace.shared.activateFileViewerSelecting([file.url])
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
