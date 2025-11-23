//
//  MainPanelView.swift
//  TrayMe
//

import SwiftUI

struct MainPanelView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @EnvironmentObject var filesManager: FilesManager
    @EnvironmentObject var notesManager: NotesManager
    @EnvironmentObject var settings: AppSettings
    
    @State private var selectedTab: PanelTab = .clipboard
    @Environment(\.openSettings) private var openSettings
    
    enum PanelTab {
        case clipboard, files, notes
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top bar with tabs
            HStack(spacing: 20) {
                TabButton(
                    title: "Clipboard",
                    icon: "doc.on.clipboard",
                    isSelected: selectedTab == .clipboard
                ) {
                    selectedTab = .clipboard
                }
                
                TabButton(
                    title: "Files",
                    icon: "folder",
                    isSelected: selectedTab == .files
                ) {
                    selectedTab = .files
                }
                
                TabButton(
                    title: "Notes",
                    icon: "note.text",
                    isSelected: selectedTab == .notes
                ) {
                    selectedTab = .notes
                }
                
                Spacer()
                
                // Settings button
                Button(action: {
                    // Close the panel first (if we can get the reference)
                    if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                        appDelegate.mainPanel?.hide()
                    }
                    // Always open settings regardless
                    openSettings()
                }) {
                    Image(systemName: "gearshape")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Content
            Group {
                switch selectedTab {
                case .clipboard:
                    ClipboardView()
                        .environmentObject(clipboardManager)
                case .files:
                    FilesView()
                        .environmentObject(filesManager)
                case .notes:
                    NotesView()
                        .environmentObject(notesManager)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow))
        .cornerRadius(12)
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// Visual effect blur for modern macOS look
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
