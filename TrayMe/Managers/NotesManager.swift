//
//  NotesManager.swift
//  TrayMe
//

import SwiftUI
import Combine
import os.log

/// Private logger for NotesManager
private let logger = Logger(subsystem: "com.trayme.TrayMe", category: "NotesManager")

class NotesManager: ObservableObject {
    @Published var notes: [Note] = []
    @Published var searchText: String = ""
    @Published var selectedNote: Note?
    
    // Debounced save to prevent excessive disk writes
    private var saveWorkItem: DispatchWorkItem?
    private let saveDebounceInterval: TimeInterval = 0.5
    
    init() {
        loadFromDisk()
        
        // Create a default note if empty
        if notes.isEmpty {
            _ = createNote()
        }
    }
    
    func createNote() -> Note {
        let newNote = Note(title: "", content: "")
        DispatchQueue.main.async {
            self.notes.insert(newNote, at: 0)
            self.selectedNote = newNote
            self.saveToDisk()
        }
        return newNote
    }
    
    func updateNote(_ note: Note, title: String? = nil, content: String? = nil) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index].update(title: title, content: content)
            saveToDisk()
        }
    }
    
    func deleteNote(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        
        if selectedNote?.id == note.id {
            selectedNote = notes.first
        }
        
        saveToDisk()
    }
    
    func togglePin(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index].isPinned.toggle()
            
            // Re-sort: pinned notes first
            notes.sort { (note1, note2) -> Bool in
                if note1.isPinned != note2.isPinned {
                    return note1.isPinned
                }
                return note1.modifiedDate > note2.modifiedDate
            }
            
            saveToDisk()
        }
    }
    
    var filteredNotes: [Note] {
        if searchText.isEmpty {
            return notes
        }
        return notes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.content.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var pinnedNotes: [Note] {
        notes.filter { $0.isPinned }
    }
    
    var unpinnedNotes: [Note] {
        notes.filter { !$0.isPinned }
    }
    
    // MARK: - Persistence
    
    private var saveURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("TrayMe", isDirectory: true)
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        return appFolder.appendingPathComponent("notes.json")
    }
    
    func saveToDisk() {
        // Cancel any pending save
        saveWorkItem?.cancel()
        
        // Create new debounced save task
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [] // Compact output for speed
            
            do {
                let data = try encoder.encode(self.notes)
                try data.write(to: self.saveURL, options: .atomic)
                logger.debug("Notes saved successfully (\(self.notes.count) notes)")
            } catch {
                logger.error("Failed to save notes: \(error.localizedDescription)")
            }
        }
        
        saveWorkItem = workItem
        
        // Execute after debounce interval
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + saveDebounceInterval, execute: workItem)
    }
    
    /// Force immediate save without debouncing (for critical operations)
    func saveImmediately() {
        saveWorkItem?.cancel()
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(notes)
            try data.write(to: saveURL, options: .atomic)
            logger.debug("Notes saved immediately (\(notes.count) notes)")
        } catch {
            logger.error("Failed to save notes immediately: \(error.localizedDescription)")
        }
    }
    
    func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: saveURL.path) else {
            logger.info("No notes file found, starting fresh")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let data = try Data(contentsOf: saveURL)
            let decoded = try decoder.decode([Note].self, from: data)
            self.notes = decoded
            self.selectedNote = decoded.first
            logger.debug("Loaded \(decoded.count) notes from disk")
        } catch {
            logger.error("Failed to load notes: \(error.localizedDescription)")
        }
    }
    
    deinit {
        // Save immediately on deinit to ensure no data loss
        saveWorkItem?.cancel()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(notes) {
            try? data.write(to: saveURL, options: .atomic)
        }
    }
}
