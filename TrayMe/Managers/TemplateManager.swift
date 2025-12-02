//
//  TemplateManager.swift
//  TrayMe
//
//  Template system for reusable text snippets with variable substitution

import SwiftUI
import Combine

/// A reusable text template with variable substitution
struct Template: Identifiable, Codable {
    let id: UUID
    var name: String
    var content: String
    var category: String?
    var variables: [String: String]  // Variable name -> default value
    var createdDate: Date
    var modifiedDate: Date
    
    init(name: String, content: String, category: String? = nil, variables: [String: String] = [:]) {
        self.id = UUID()
        self.name = name
        self.content = content
        self.category = category
        self.variables = variables
        self.createdDate = Date()
        self.modifiedDate = Date()
    }
    
    /// Built-in variables that are automatically substituted
    static let builtInVariables: [String: () -> String] = [
        "date": { DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none) },
        "time": { DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short) },
        "datetime": { DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short) },
        "year": { String(Calendar.current.component(.year, from: Date())) },
        "month": { DateFormatter().monthSymbols[Calendar.current.component(.month, from: Date()) - 1] },
        "day": { String(Calendar.current.component(.day, from: Date())) },
        "weekday": { DateFormatter().weekdaySymbols[Calendar.current.component(.weekday, from: Date()) - 1] },
        "timestamp": { String(Int(Date().timeIntervalSince1970)) },
        "uuid": { UUID().uuidString },
    ]
    
    /// Expand the template with variable substitution
    /// - Parameters:
    ///   - clipboard: Current clipboard content to substitute for ${clipboard}
    ///   - customValues: Custom variable values to override defaults
    /// - Returns: Expanded template content
    func expand(clipboard: String? = nil, customValues: [String: String] = [:]) -> String {
        var result = content
        
        // Substitute built-in variables
        for (name, valueGenerator) in Template.builtInVariables {
            result = result.replacingOccurrences(of: "${\(name)}", with: valueGenerator())
        }
        
        // Substitute clipboard
        if let clipboardContent = clipboard {
            result = result.replacingOccurrences(of: "${clipboard}", with: clipboardContent)
        }
        
        // Substitute custom variables (prefer customValues, fall back to defaults)
        for (name, defaultValue) in variables {
            let value = customValues[name] ?? defaultValue
            result = result.replacingOccurrences(of: "${\(name)}", with: value)
        }
        
        return result
    }
    
    /// Extract variable names from the template content
    var extractedVariables: [String] {
        let pattern = #"\$\{([^}]+)\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        
        let matches = regex.matches(in: content, options: [], range: NSRange(content.startIndex..., in: content))
        var variables: [String] = []
        
        for match in matches {
            if let range = Range(match.range(at: 1), in: content) {
                let varName = String(content[range])
                // Exclude built-in variables
                if !Template.builtInVariables.keys.contains(varName) && varName != "clipboard" {
                    variables.append(varName)
                }
            }
        }
        
        return Array(Set(variables))
    }
}

/// Manager for templates
class TemplateManager: ObservableObject {
    @Published var templates: [Template] = []
    @Published var categories: [String] = []
    
    private let saveKey = "TrayMe.Templates"
    
    init() {
        loadTemplates()
        if templates.isEmpty {
            addDefaultTemplates()
        }
        updateCategories()
    }
    
    func loadTemplates() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Template].self, from: data) {
            templates = decoded
        }
    }
    
    func saveTemplates() {
        if let data = try? JSONEncoder().encode(templates) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
        updateCategories()
    }
    
    func addTemplate(_ template: Template) {
        templates.append(template)
        saveTemplates()
    }
    
    func updateTemplate(_ template: Template) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            var updated = template
            updated.modifiedDate = Date()
            templates[index] = updated
            saveTemplates()
        }
    }
    
    func deleteTemplate(_ template: Template) {
        templates.removeAll { $0.id == template.id }
        saveTemplates()
    }
    
    func templates(in category: String?) -> [Template] {
        if let category = category {
            return templates.filter { $0.category == category }
        }
        return templates
    }
    
    private func updateCategories() {
        let allCategories = templates.compactMap { $0.category }
        categories = Array(Set(allCategories)).sorted()
    }
    
    private func addDefaultTemplates() {
        let defaults = [
            Template(
                name: "Date Stamp",
                content: "Date: ${date}",
                category: "Utility"
            ),
            Template(
                name: "Timestamp",
                content: "[${datetime}] ",
                category: "Utility"
            ),
            Template(
                name: "Email Signature",
                content: """
                Best regards,
                ${name}
                
                ${date}
                """,
                category: "Email",
                variables: ["name": "Your Name"]
            ),
            Template(
                name: "Meeting Notes",
                content: """
                # Meeting Notes - ${date}
                
                ## Attendees
                - ${attendees}
                
                ## Agenda
                1. 
                
                ## Action Items
                - [ ] 
                
                ## Notes
                
                """,
                category: "Work",
                variables: ["attendees": ""]
            ),
            Template(
                name: "Bug Report",
                content: """
                ## Bug Report
                
                **Date:** ${date}
                **Version:** ${version}
                
                ### Steps to Reproduce
                1. 
                
                ### Expected Behavior
                
                ### Actual Behavior
                
                ### Additional Context
                ${clipboard}
                """,
                category: "Development",
                variables: ["version": "1.0.0"]
            ),
            Template(
                name: "Code Review Comment",
                content: """
                **Review Comment** (${datetime})
                
                File: ${file}
                Line: ${line}
                
                ${comment}
                """,
                category: "Development",
                variables: ["file": "", "line": "", "comment": ""]
            ),
        ]
        
        templates = defaults
        saveTemplates()
    }
}

/// Template picker/insertion view
struct TemplatePickerView: View {
    @ObservedObject var manager: TemplateManager
    let clipboardContent: String?  // Passed in from parent
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedCategory: String?
    @State private var expandingTemplate: Template?
    @State private var customValues: [String: String] = [:]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Templates")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()
            
            Divider()
            
            HStack(spacing: 0) {
                // Categories sidebar
                VStack(alignment: .leading, spacing: 4) {
                    Button(action: { selectedCategory = nil }) {
                        HStack {
                            Image(systemName: "tray.full")
                            Text("All Templates")
                        }
                        .foregroundColor(selectedCategory == nil ? .accentColor : .primary)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    
                    ForEach(manager.categories, id: \.self) { category in
                        Button(action: { selectedCategory = category }) {
                            HStack {
                                Image(systemName: "folder")
                                Text(category)
                            }
                            .foregroundColor(selectedCategory == category ? .accentColor : .primary)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    }
                    
                    Spacer()
                }
                .frame(width: 150)
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Templates list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(manager.templates(in: selectedCategory)) { template in
                            TemplateRowView(
                                template: template,
                                onSelect: {
                                    if template.extractedVariables.isEmpty {
                                        // No custom variables, expand directly
                                        let expanded = template.expand(clipboard: clipboardContent)
                                        onSelect(expanded)
                                        dismiss()
                                    } else {
                                        // Show variable input
                                        expandingTemplate = template
                                        customValues = template.variables
                                    }
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 500, height: 400)
        .sheet(item: $expandingTemplate) { template in
            TemplateExpandView(
                template: template,
                clipboardContent: clipboardContent,
                customValues: $customValues,
                onExpand: { expanded in
                    onSelect(expanded)
                    expandingTemplate = nil
                    dismiss()
                },
                onCancel: {
                    expandingTemplate = nil
                }
            )
        }
    }
}

struct TemplateRowView: View {
    let template: Template
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(template.name)
                        .font(.system(size: 14, weight: .medium))
                    
                    Spacer()
                    
                    if let category = template.category {
                        Text(category)
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
                
                Text(template.content.prefix(100) + (template.content.count > 100 ? "..." : ""))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct TemplateExpandView: View {
    let template: Template
    let clipboardContent: String?  // Passed in from parent
    @Binding var customValues: [String: String]
    let onExpand: (String) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Fill Template Variables")
                .font(.headline)
            
            Form {
                ForEach(template.extractedVariables, id: \.self) { variable in
                    HStack {
                        Text(variable)
                            .frame(width: 100, alignment: .trailing)
                        TextField("Value", text: Binding(
                            get: { customValues[variable] ?? "" },
                            set: { customValues[variable] = $0 }
                        ))
                    }
                }
            }
            
            // Preview
            GroupBox("Preview") {
                Text(template.expand(
                    clipboard: clipboardContent,
                    customValues: customValues
                ))
                .font(.system(size: 12, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
            
            HStack {
                Button("Cancel", action: onCancel)
                Spacer()
                Button("Insert") {
                    let expanded = template.expand(
                        clipboard: clipboardContent,
                        customValues: customValues
                    )
                    onExpand(expanded)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400, height: 350)
    }
}
