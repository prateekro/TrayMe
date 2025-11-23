//
//  NotesManager.swift
//  TrayMe
//

import SwiftUI
internal import Combine

class NotesManager: ObservableObject {
    @Published var notes: [Note] = []
    @Published var searchText: String = ""
    @Published var selectedNote: Note?
    
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
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(notes) {
            try? data.write(to: saveURL)
        }
    }
    
    func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: saveURL.path) else { return }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        if let data = try? Data(contentsOf: saveURL),
           let decoded = try? decoder.decode([Note].self, from: data) {
            self.notes = decoded
            self.selectedNote = decoded.first
        }
    }
}
