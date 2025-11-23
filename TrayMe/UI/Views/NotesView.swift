//
//  NotesView.swift
//  TrayMe
//

import SwiftUI

struct NotesView: View {
    @EnvironmentObject var manager: NotesManager
    @State private var noteContent: String = ""
    @State private var noteTitle: String = ""
    @FocusState private var isEditorFocused: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            // Notes list sidebar
            VStack(spacing: 0) {
                // Search and new note
                HStack(spacing: 8) {
                    TextField("Search...", text: $manager.searchText)
                        .textFieldStyle(.plain)
                        .padding(6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                    
                    Button(action: {
                        let newNote = manager.createNote()
                        noteTitle = newNote.title
                        noteContent = newNote.content
                        isEditorFocused = true
                    }) {
                        Image(systemName: "square.and.pencil")
                    }
                    .buttonStyle(.plain)
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
                            .onTapGesture {
                                selectNote(note)
                            }
                        }
                    }
                }
            }
            .frame(width: 220)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // Note editor
            if let selectedNote = manager.selectedNote {
                VStack(spacing: 0) {
                    // Title field
                    TextField("Title", text: $noteTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 18, weight: .semibold))
                        .padding()
                        .onChange(of: noteTitle) {
                            manager.updateNote(selectedNote, title: noteTitle)
                        }
                    
                    Divider()
                    
                    // Content editor
                    TextEditor(text: $noteContent)
                        .font(.system(size: 14))
                        .padding(8)
                        .focused($isEditorFocused)
                        .onChange(of: noteContent) {
                            manager.updateNote(selectedNote, content: noteContent)
                        }
                    
                    // Footer with actions
                    HStack {
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
                        
                        Spacer()
                        
                        Text("Modified \(selectedNote.modifiedDate, formatter: dateFormatter)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            manager.deleteNote(selectedNote)
                            if let firstNote = manager.notes.first {
                                selectNote(firstNote)
                            }
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
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
            if let selectedNote = manager.selectedNote {
                selectNote(selectedNote)
            }
        }
    }
    
    func selectNote(_ note: Note) {
        manager.selectedNote = note
        noteTitle = note.title
        noteContent = note.content
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
}

struct NoteListItem: View {
    @EnvironmentObject var manager: NotesManager
    let note: Note
    let isSelected: Bool
    
    var body: some View {
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
            }
            
            if !note.content.isEmpty {
                Text(note.preview)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Text(note.modifiedDate, formatter: relativeDateFormatter)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        )
        .padding(.horizontal, 4)
    }
    
    private var relativeDateFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }
}
