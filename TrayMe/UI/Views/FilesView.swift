//
//  FilesView.swift
//  TrayMe
//

import SwiftUI
import UniformTypeIdentifiers

struct FilesView: View {
    @EnvironmentObject var manager: FilesManager
    @State private var hoveredFile: UUID?
    @State private var isDragging = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search files...", text: $manager.searchText)
                    .textFieldStyle(.plain)
                
                if !manager.searchText.isEmpty {
                    Button(action: { manager.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding()
            
            // Drop zone or file list
            if manager.files.isEmpty {
                // Empty state with drop zone
                DropZoneView(isDragging: $isDragging)
            } else {
                // Files grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 12)
                    ], spacing: 12) {
                        ForEach(manager.filteredFiles) { file in
                            FileCard(
                                file: file,
                                isHovered: hoveredFile == file.id
                            )
                            .onHover { hovering in
                                hoveredFile = hovering ? file.id : nil
                            }
                        }
                    }
                    .padding()
                }
                .background(
                    DropZoneView(isDragging: $isDragging)
                        .opacity(isDragging ? 0.5 : 0)
                )
            }
            
            // Footer
            HStack {
                Text("\(manager.files.count) files")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if !manager.files.isEmpty {
                    Button("Clear All") {
                        manager.clearAll()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        }
        .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
            handleDrop(providers: providers)
            return true
        }
    }
    
    func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        manager.addFile(url: url)
                    }
                }
            }
        }
    }
}

struct DropZoneView: View {
    @Binding var isDragging: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 48))
                .foregroundColor(isDragging ? .accentColor : .secondary)
            
            Text("Drop files here")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isDragging ? .accentColor : .primary)
            
            Text("Files will be temporarily stored for easy access")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isDragging ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [8])
                )
                .padding(20)
        )
    }
}

struct FileCard: View {
    @EnvironmentObject var manager: FilesManager
    let file: FileItem
    let isHovered: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            // File icon
            if let icon = file.icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
            } else {
                Image(systemName: "doc")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
            }
            
            // File name
            Text(file.name)
                .font(.system(size: 11))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            
            // File size
            Text(file.formattedSize)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            
            // Actions (visible on hover)
            if isHovered {
                HStack(spacing: 4) {
                    Button(action: {
                        manager.openFile(file)
                    }) {
                        Image(systemName: "arrow.up.forward.square")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        manager.revealInFinder(file)
                    }) {
                        Image(systemName: "folder")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        manager.removeFile(file)
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
        }
        .frame(width: 100, height: 120)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        )
        .onDrag {
            NSItemProvider(object: file.url as NSURL)
        }
    }
}
