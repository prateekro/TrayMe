//
//  NotesView.swift
//  TrayMe
//

import SwiftUI
import AppKit

// Static formatters for performance
private let sharedDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()

private let sharedRelativeDateFormatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter
}()

struct NotesView: View {
    @EnvironmentObject var manager: NotesManager
    @State private var noteContent: String = ""
    @State private var noteTitle: String = ""
    @State private var saveWorkItem: DispatchWorkItem?
    @State private var showSortMenu = false
    @State private var showColorPicker = false
    @State private var showExportSuccess = false
    @State private var showDeleteConfirmation = false
    @FocusState private var isEditorFocused: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            // Notes list sidebar
            VStack(spacing: 0) {
                // Search and controls
                HStack(spacing: 8) {
                    TextField("Search...", text: $manager.searchText)
                        .textFieldStyle(.plain)
                        .padding(6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                    
                    // Sort button
                    Menu {
                        ForEach(NoteSortOption.allCases, id: \.self) { option in
                            Button(action: {
                                manager.setSortOption(option)
                            }) {
                                HStack {
                                    Text(option.rawValue)
                                    if manager.sortOption == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundColor(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 20)
                    .help("Sort notes")
                    
                    Button(action: {
                        print("📝 Creating new note...")
                        let newNote = manager.createNote()
                        noteTitle = newNote.title
                        noteContent = newNote.content
                        isEditorFocused = true
                        print("📝 New note created: \(newNote.id)")
                    }) {
                        Image(systemName: "square.and.pencil")
                    }
                    .buttonStyle(.plain)
                    .help("New note (⌘N)")
                }
                .padding(8)
                
                Divider()
                
                // Notes list
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(manager.filteredNotes) { note in
                            NoteListItem(
                                note: note,
                                isSelected: manager.selectedNote?.id == note.id
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectNote(note)
                            }
                            .contextMenu {
                                Button(action: {
                                    manager.togglePin(note)
                                }) {
                                    Label(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin")
                                }
                                
                                Divider()
                                
                                Button(action: {
                                    _ = manager.duplicateNote(note)
                                }) {
                                    Label("Duplicate", systemImage: "doc.on.doc")
                                }
                                
                                Button(action: {
                                    manager.copyNoteToClipboard(note)
                                }) {
                                    Label("Copy to Clipboard", systemImage: "doc.on.clipboard")
                                }
                                
                                Button(action: {
                                    if let url = manager.exportNoteToFile(note) {
                                        NSWorkspace.shared.activateFileViewerSelecting([url])
                                    }
                                }) {
                                    Label("Export to File...", systemImage: "square.and.arrow.up")
                                }
                                
                                Divider()
                                
                                Menu("Color") {
                                    ForEach(NoteColor.allCases, id: \.self) { color in
                                Button(action: {
                                            manager.setNoteColor(note, color: color)
                                        }) {
                                            HStack {
                                                if color != .none {
                                                    Circle()
                                                        .fill(color.swiftUIColor)
                                                        .frame(width: 10, height: 10)
                                                }
                                                Text(color.displayName)
                                                if note.color == color {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                Divider()
                                
                                Button(role: .destructive, action: {
                                    performDeleteNote(note)
                                }) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                
                // Footer with note count
                HStack {
                    Text("\(manager.notes.count) notes")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(manager.totalWordCount) words")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
            }
            .frame(width: 220)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // Note editor
            if let selectedNote = manager.selectedNote {
                VStack(spacing: 0) {
                    // Title field with color indicator
                    HStack(spacing: 8) {
                        if selectedNote.color != .none {
                            Circle()
                                .fill(selectedNote.color.swiftUIColor)
                                .frame(width: 12, height: 12)
                        }
                        
                        TextField("Title", text: $noteTitle)
                            .textFieldStyle(.plain)
                            .font(.system(size: 18, weight: .semibold))
                            .onChange(of: noteTitle) { oldValue, newValue in
                                guard let selectedNote = manager.selectedNote else { return }
                                
                                saveWorkItem?.cancel()
                                
                                let workItem = DispatchWorkItem { [weak manager] in
                                    manager?.updateNote(selectedNote, title: newValue)
                                    print("📝 Auto-saved title: \(newValue)")
                                }
                                saveWorkItem = workItem
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
                            }
                        
                        Spacer()
                        
                        // Quick actions in header
                        HStack(spacing: 12) {
                            // Color picker
                            Menu {
                                ForEach(NoteColor.allCases, id: \.self) { color in
                                    Button(action: {
                                        manager.setNoteColor(selectedNote, color: color)
                                    }) {
                                        HStack {
                                            if color != .none {
                                                Circle()
                                                    .fill(color.swiftUIColor)
                                                    .frame(width: 10, height: 10)
                                            }
                                            Text(color.displayName)
                                            if selectedNote.color == color {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "paintpalette")
                                    .foregroundColor(.secondary)
                            }
                            .menuStyle(.borderlessButton)
                            .frame(width: 20)
                            .help("Set color")
                            
                            // Copy button
                            Button(action: {
                                manager.copyNoteToClipboard(selectedNote)
                                showExportSuccess = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    showExportSuccess = false
                                }
                            }) {
                                Image(systemName: "doc.on.clipboard")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Copy to clipboard (⌘C)")
                            
                            // Duplicate button
                            Button(action: {
                                let duplicated = manager.duplicateNote(selectedNote)
                                selectNote(duplicated)
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Duplicate note")
                            
                            // Export button
                            Button(action: {
                                if let url = manager.exportNoteToFile(selectedNote) {
                                    NSWorkspace.shared.activateFileViewerSelecting([url])
                                }
                            }) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Export to file")
                        }
                    }
                    .padding()
                    
                    // Copied success indicator
                    if showExportSuccess {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Copied to clipboard")
                                .font(.system(size: 12))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal)
                        .transition(.opacity)
                    }
                    
                    Divider()
                    
                    // Content editor
                    TextEditor(text: $noteContent)
                        .font(.system(size: 14))
                        .padding(8)
                        .focused($isEditorFocused)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onChange(of: noteContent) { oldValue, newValue in
                            guard let selectedNote = manager.selectedNote else { return }
                            
                            saveWorkItem?.cancel()
                            
                            let workItem = DispatchWorkItem { [weak manager] in
                                manager?.updateNote(selectedNote, content: newValue)
                                print("📝 Auto-saved content")
                            }
                            saveWorkItem = workItem
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
                        }
                    
                    // Enhanced footer with stats and actions
                    HStack(spacing: 16) {
                        // Pin button
                        Button(action: {
                            manager.togglePin(selectedNote)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: selectedNote.isPinned ? "pin.fill" : "pin")
                                Text(selectedNote.isPinned ? "Pinned" : "Pin")
                            }
                            .font(.system(size: 11))
                            .foregroundColor(selectedNote.isPinned ? .accentColor : .secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Pin note (⌘P)")
                        
                        Divider()
                            .frame(height: 12)
                        
                        // Word/character count
                        Text("\(selectedNote.wordCount) words")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text("\(selectedNote.characterCount) chars")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text("\(selectedNote.lineCount) lines")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Timestamps
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Created: \(selectedNote.createdDate, formatter: sharedDateFormatter)")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text("Modified: \(selectedNote.modifiedDate, formatter: sharedDateFormatter)")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                            .frame(height: 12)
                        
                        // Delete button
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        .help("Delete note (⌘⌫)")
                        .alert("Delete Note?", isPresented: $showDeleteConfirmation) {
                            Button("Cancel", role: .cancel) { }
                            Button("Delete", role: .destructive) {
                                performDeleteNote(selectedNote)
                            }
                        } message: {
                            Text("Are you sure you want to delete \"\(selectedNote.displayTitle)\"? This action cannot be undone.")
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
                }
            } else {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "note.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No note selected")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    
                    Button("Create New Note") {
                        let newNote = manager.createNote()
                        selectNote(newNote)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            print("📝 NotesView appeared. Notes count: \(manager.notes.count)")
            if let selectedNote = manager.selectedNote {
                print("📝 Selected note: \(selectedNote.displayTitle)")
                selectNote(selectedNote)
            } else {
                print("📝 No note selected")
            }
        }
        .onDisappear {
            saveWorkItem?.cancel()
            
            if let currentNote = manager.selectedNote {
                print("📝 Saving note on disappear: \(currentNote.displayTitle)")
                manager.updateNote(currentNote, title: noteTitle, content: noteContent)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusNotes)) { _ in
            print("📝 FocusNotes notification received!")
            isEditorFocused = true
            print("📝 Set isEditorFocused = true")
        }
    }
    
    func selectNote(_ note: Note) {
        print("📝 Selecting note: \(note.displayTitle)")
        
        saveWorkItem?.cancel()
        
        if let currentNote = manager.selectedNote,
           currentNote.id != note.id {
            print("📝 Saving previous note before switching")
            manager.updateNote(currentNote, title: noteTitle, content: noteContent)
        }
        
        manager.selectedNote = note
        noteTitle = note.title
        noteContent = note.content
    }
    
    func performDeleteNote(_ note: Note) {
        manager.deleteNote(note)
        if let firstNote = manager.notes.first {
            selectNote(firstNote)
        }
    }
}

struct NoteListItem: View {
    @EnvironmentObject var manager: NotesManager
    let note: Note
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            // Color indicator bar
            if note.color != .none {
                Rectangle()
                    .fill(note.color.swiftUIColor)
                    .frame(width: 3)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if note.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.accentColor)
                    }
                    
                    Text(note.displayTitle)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Word count badge
                    Text("\(note.wordCount)w")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(4)
                }
                
                if !note.content.isEmpty {
                    Text(note.preview)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Text(note.modifiedDate, formatter: sharedRelativeDateFormatter)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(8)
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        )
        .padding(.horizontal, 4)
    }
}
