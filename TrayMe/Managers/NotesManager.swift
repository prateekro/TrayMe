//
//  NotesManager.swift
//  TrayMe
//

import SwiftUI
import Combine
import AppKit

enum NoteSortOption: String, CaseIterable {
    case modifiedDate = "Modified Date"
    case createdDate = "Created Date"
    case alphabetical = "Alphabetical"
    case wordCount = "Word Count"
}

class NotesManager: ObservableObject {
    @Published var notes: [Note] = []
    @Published var searchText: String = ""
    @Published var selectedNote: Note?
    @Published var sortOption: NoteSortOption = .modifiedDate
    
    init() {
        loadFromDisk()
        
        // Create a default note if empty
        if notes.isEmpty {
            _ = createNote()
        }
    }
    
    func createNote(title: String = "", content: String = "", color: NoteColor = .none) -> Note {
        let newNote = Note(title: title, content: content, color: color)
        DispatchQueue.main.async {
            self.notes.insert(newNote, at: 0)
            self.selectedNote = newNote
            self.saveToDisk()
        }
        return newNote
    }
    
    func duplicateNote(_ note: Note) -> Note {
        let duplicated = Note(
            title: note.title.isEmpty ? "" : "\(note.title) (Copy)",
            content: note.content,
            isPinned: false,
            color: note.color
        )
        DispatchQueue.main.async {
            // Insert right after the original
            if let index = self.notes.firstIndex(where: { $0.id == note.id }) {
                self.notes.insert(duplicated, at: index + 1)
            } else {
                self.notes.insert(duplicated, at: 0)
            }
            self.selectedNote = duplicated
            self.saveToDisk()
        }
        return duplicated
    }
    
    func updateNote(_ note: Note, title: String? = nil, content: String? = nil, color: NoteColor? = nil) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index].update(title: title, content: content, color: color)
            saveToDisk()
        }
    }
    
    func setNoteColor(_ note: Note, color: NoteColor) {
        updateNote(note, color: color)
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
            sortNotes()
            
            saveToDisk()
        }
    }
    
    func copyNoteToClipboard(_ note: Note) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        var textToCopy = ""
        if !note.title.isEmpty {
            textToCopy = note.title + "\n\n"
        }
        textToCopy += note.content
        
        pasteboard.setString(textToCopy, forType: .string)
    }
    
    func exportNoteToFile(_ note: Note) -> URL? {
        let fileName = note.displayTitle.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("\(fileName).txt")
        
        var textContent = ""
        if !note.title.isEmpty {
            textContent = note.title + "\n\n"
        }
        textContent += note.content
        textContent += "\n\n---\nCreated: \(note.createdDate)\nModified: \(note.modifiedDate)"
        
        do {
            try textContent.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Failed to export note: \(error)")
            return nil
        }
    }
    
    func setSortOption(_ option: NoteSortOption) {
        sortOption = option
        sortNotes()
        saveToDisk()
    }
    
    private func sortNotes() {
        notes.sort { (note1, note2) -> Bool in
            // Pinned notes always first
            if note1.isPinned != note2.isPinned {
                return note1.isPinned
            }
            
            switch sortOption {
            case .modifiedDate:
                return note1.modifiedDate > note2.modifiedDate
            case .createdDate:
                return note1.createdDate > note2.createdDate
            case .alphabetical:
                return note1.displayTitle.localizedCaseInsensitiveCompare(note2.displayTitle) == .orderedAscending
            case .wordCount:
                return note1.wordCount > note2.wordCount
            }
        }
    }
    
    var filteredNotes: [Note] {
        var result = notes
        
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.content.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
    }
    
    var pinnedNotes: [Note] {
        notes.filter { $0.isPinned }
    }
    
    var unpinnedNotes: [Note] {
        notes.filter { !$0.isPinned }
    }
    
    var totalWordCount: Int {
        notes.reduce(0) { $0 + $1.wordCount }
    }
    
    var totalCharacterCount: Int {
        notes.reduce(0) { $0 + $1.characterCount }
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
