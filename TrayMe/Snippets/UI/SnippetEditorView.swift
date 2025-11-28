//
//  SnippetEditorView.swift
//  TrayMe
//
//  Editor for creating and editing snippets

import SwiftUI

struct SnippetEditorView: View {
    @EnvironmentObject var manager: SnippetManager
    @Environment(\.dismiss) private var dismiss
    
    let snippet: Snippet?
    
    @State private var trigger: String = ""
    @State private var expansion: String = ""
    @State private var category: String = ""
    @State private var showVariablePicker = false
    @State private var conflictWarning: String?
    @State private var triggerError: String?
    
    private var isEditing: Bool { snippet != nil }
    
    init(snippet: Snippet? = nil) {
        self.snippet = snippet
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isEditing ? "Edit Snippet" : "New Snippet")
                    .font(.title2.bold())
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Trigger field
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Trigger")
                                .font(.headline)
                            
                            Spacer()
                            
                            if let error = triggerError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        TextField("e.g., //email", text: $trigger)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .onChange(of: trigger) { _, newValue in
                                validateTrigger(newValue)
                            }
                        
                        Text("Type this text to trigger the expansion. Use a prefix like // or :: to avoid accidental triggers.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let warning = conflictWarning {
                            Label(warning, systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    // Expansion field
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Expansion")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(action: { showVariablePicker = true }) {
                                Label("Insert Variable", systemImage: "curlybraces")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        
                        TextEditor(text: $expansion)
                            .font(.system(.body))
                            .frame(minHeight: 150)
                            .padding(4)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                            )
                        
                        // Detected variables
                        let variables = Snippet.extractVariables(from: expansion)
                        if !variables.isEmpty {
                            HStack {
                                Text("Variables:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                ForEach(variables, id: \.self) { variable in
                                    Text(variable)
                                        .font(.system(size: 10, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                    
                    // Category picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                            .font(.headline)
                        
                        Picker("Category", selection: $category) {
                            Text("None").tag("")
                            
                            ForEach(manager.categories) { cat in
                                Label(cat.name, systemImage: cat.icon)
                                    .tag(cat.name)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    // Preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(.headline)
                        
                        let previewText = Snippet(trigger: trigger, expansion: expansion).expand()
                        
                        Text(previewText)
                            .font(.system(.body))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Footer
            HStack {
                if isEditing {
                    Button(role: .destructive, action: deleteSnippet) {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                }
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Button(isEditing ? "Save" : "Create") {
                    saveSnippet()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
                .keyboardShortcut(.return)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 500, height: 600)
        .onAppear {
            if let snippet = snippet {
                trigger = snippet.trigger
                expansion = snippet.expansion
                category = snippet.category ?? ""
            }
        }
        .sheet(isPresented: $showVariablePicker) {
            VariablePickerView { variable in
                expansion += variable.rawValue
            }
        }
    }
    
    // MARK: - Validation
    
    private var isValid: Bool {
        !trigger.isEmpty && !expansion.isEmpty && triggerError == nil
    }
    
    private func validateTrigger(_ newTrigger: String) {
        triggerError = nil
        conflictWarning = nil
        
        guard !newTrigger.isEmpty else { return }
        
        // Check length
        if newTrigger.count < 2 {
            triggerError = "Trigger must be at least 2 characters"
            return
        }
        
        // Check for spaces
        if newTrigger.contains(" ") {
            triggerError = "Trigger cannot contain spaces"
            return
        }
        
        // Check for conflicts
        if let conflict = manager.hasConflict(for: newTrigger, excluding: snippet?.id) {
            conflictWarning = "Conflicts with '\(conflict.trigger)'"
        }
    }
    
    // MARK: - Actions
    
    private func saveSnippet() {
        if let existing = snippet {
            // Update existing
            var updated = existing
            updated.trigger = trigger
            updated.expansion = expansion
            updated.category = category.isEmpty ? nil : category
            updated.refreshVariables()
            manager.updateSnippet(updated)
        } else {
            // Create new
            manager.createSnippet(
                trigger: trigger,
                expansion: expansion,
                category: category.isEmpty ? nil : category
            )
        }
        
        dismiss()
    }
    
    private func deleteSnippet() {
        if let snippet = snippet {
            manager.deleteSnippet(snippet)
        }
        dismiss()
    }
}

// MARK: - Variable Picker

struct VariablePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (BuiltInVariable) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Insert Variable")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(BuiltInVariable.allCases, id: \.rawValue) { variable in
                        Button(action: {
                            onSelect(variable)
                            dismiss()
                        }) {
                            HStack {
                                Text(variable.rawValue)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.accentColor)
                                
                                Spacer()
                                
                                VStack(alignment: .trailing) {
                                    Text(variable.displayName)
                                        .font(.caption)
                                    
                                    Text(variable.description)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
        .frame(width: 400, height: 400)
    }
}

// MARK: - Preview

#Preview {
    SnippetEditorView()
        .environmentObject(SnippetManager.shared)
}
