//
//  NotesView.swift
//  TrayMe
//

import SwiftUI

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
    @State private var viewMode: NoteViewMode = .edit
    @State private var renderedContent: AttributedString = AttributedString("")
    @State private var renderWorkItem: DispatchWorkItem?
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
                            .contentShape(Rectangle()) // Make entire row clickable
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
                    // Header with title and view mode toggle
                    HStack {
                        TextField("Title", text: $noteTitle)
                            .textFieldStyle(.plain)
                            .font(.system(size: 18, weight: .semibold))
                            .onChange(of: noteTitle) { oldValue, newValue in
                                guard let selectedNote = manager.selectedNote else { return }
                                
                                // Cancel previous save
                                saveWorkItem?.cancel()
                                
                                // Create new debounced save
                                let workItem = DispatchWorkItem { [weak manager] in
                                    manager?.updateNote(selectedNote, title: newValue)
                                    print("📝 Auto-saved title: \(newValue)")
                                }
                                saveWorkItem = workItem
                                
                                // Execute after 0.5 seconds
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
                            }
                        
                        Spacer()
                        
                        // View mode picker
                        viewModePicker
                    }
                    .padding()
                    
                    Divider()
                    
                    // Content area based on view mode
                    contentArea
                    
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
                        
                        Text("Modified \(selectedNote.modifiedDate, formatter: sharedDateFormatter)")
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
            print("📝 NotesView appeared. Notes count: \(manager.notes.count)")
            if let selectedNote = manager.selectedNote {
                print("📝 Selected note: \(selectedNote.displayTitle)")
                selectNote(selectedNote)
            } else {
                print("📝 No note selected")
            }
        }
        .onDisappear {
            // Cancel pending save and save immediately
            saveWorkItem?.cancel()
            
            // Save current note when view disappears
            if let currentNote = manager.selectedNote {
                print("📝 Saving note on disappear: \(currentNote.displayTitle)")
                manager.updateNote(currentNote, title: noteTitle, content: noteContent)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusNotes)) { _ in
            print("📝 FocusNotes notification received!")
            // Focus editor when panel shows (unless dragging files)
            // No delay needed - animation is already complete when this fires
            isEditorFocused = true
            print("📝 Set isEditorFocused = true")
        }
    }
    
    // MARK: - View Mode Picker
    
    private var viewModePicker: some View {
        HStack(spacing: 2) {
            ForEach(NoteViewMode.allCases, id: \.self) { mode in
                Button(action: {
                    viewMode = mode
                    if mode != .edit {
                        updateRenderedContent()
                    }
                }) {
                    Image(systemName: mode.icon)
                        .font(.system(size: 12))
                        .foregroundColor(viewMode == mode ? .white : .secondary)
                        .frame(width: 24, height: 20)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(viewMode == mode ? Color.accentColor : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .help(mode.rawValue)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    // MARK: - Content Area
    
    @ViewBuilder
    private var contentArea: some View {
        switch viewMode {
        case .edit:
            editorView
        case .preview:
            previewView
        case .split:
            splitView
        }
    }
    
    private var editorView: some View {
        TextEditor(text: $noteContent)
            .font(.system(size: 14, design: .monospaced))
            .padding(8)
            .focused($isEditorFocused)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: noteContent) { oldValue, newValue in
                handleContentChange(newValue)
            }
    }
    
    private var previewView: some View {
        ScrollView {
            Text(renderedContent)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
    }
    
    private var splitView: some View {
        HSplitView {
            // Editor side
            TextEditor(text: $noteContent)
                .font(.system(size: 14, design: .monospaced))
                .padding(8)
                .focused($isEditorFocused)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: noteContent) { oldValue, newValue in
                    handleContentChange(newValue)
                }
            
            // Preview side
            ScrollView {
                Text(renderedContent)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.textBackgroundColor))
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleContentChange(_ newValue: String) {
        guard let selectedNote = manager.selectedNote else { return }
        
        // Cancel previous save
        saveWorkItem?.cancel()
        
        // Create new debounced save
        let workItem = DispatchWorkItem { [weak manager] in
            manager?.updateNote(selectedNote, content: newValue)
            print("📝 Auto-saved content")
        }
        saveWorkItem = workItem
        
        // Execute after 0.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
        
        // Update markdown preview with debounce (300ms)
        if viewMode != .edit {
            renderWorkItem?.cancel()
            let renderWork = DispatchWorkItem {
                updateRenderedContent()
            }
            renderWorkItem = renderWork
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: renderWork)
        }
    }
    
    private func updateRenderedContent() {
        renderedContent = MarkdownRenderer.renderFull(noteContent)
    }
    
    func selectNote(_ note: Note) {
        print("📝 Selecting note: \(note.displayTitle)")
        
        // Execute any pending save immediately
        saveWorkItem?.cancel()
        
        // Save current note before switching
        if let currentNote = manager.selectedNote,
           currentNote.id != note.id {
            print("📝 Saving previous note before switching")
            manager.updateNote(currentNote, title: noteTitle, content: noteContent)
        }
        
        manager.selectedNote = note
        noteTitle = note.title
        noteContent = note.content
        
        // Update rendered content for preview modes
        if viewMode != .edit {
            updateRenderedContent()
        }
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
            
            Text(note.modifiedDate, formatter: sharedRelativeDateFormatter)
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
}
