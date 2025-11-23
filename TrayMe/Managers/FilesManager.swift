//
//  FilesManager.swift
//  TrayMe
//

import SwiftUI
import AppKit
internal import Combine

class FilesManager: ObservableObject {
    @Published var files: [FileItem] = []
    @Published var searchText: String = ""
    
    private let maxFiles = 50
    
    init() {
        loadFromDisk()
    }

    func addFile(url: URL) {
        // Check if file already exists
        if files.contains(where: { $0.url == url }) {
            return
        }
        
        // Security-scoped bookmark for later access
        let newFile = FileItem(url: url)
        
        DispatchQueue.main.async {
            self.files.insert(newFile, at: 0)
            
            // Limit number of files
            if self.files.count > self.maxFiles {
                self.files = Array(self.files.prefix(self.maxFiles))
            }
            
            self.saveToDisk()
        }
    }
    
    func addFiles(urls: [URL]) {
        urls.forEach { addFile(url: $0) }
    }
    
    func removeFile(_ file: FileItem) {
        files.removeAll { $0.id == file.id }
        saveToDisk()
    }
    
    func clearAll() {
        files.removeAll()
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
