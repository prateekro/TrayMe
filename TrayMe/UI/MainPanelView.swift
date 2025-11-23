//
//  MainPanelView.swift
//  TrayMe
//

import SwiftUI
import Combine

class PanelState: ObservableObject {
    @Published var selectedTab: PanelTab = .clipboard
    
    enum PanelTab {
        case clipboard, files, notes
    }
}

struct MainPanelView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @EnvironmentObject var filesManager: FilesManager
    @EnvironmentObject var notesManager: NotesManager
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var panelState: PanelState
    
    @Environment(\.openSettings) private var openSettings
    
    var body: some View {
        VStack(spacing: 0) {
            // Top bar with section titles and settings
            HStack(spacing: 0) {
                // Clipboard header
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard")
                    Text("Clipboard")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(panelState.selectedTab == .clipboard ? .accentColor : .primary)
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 20)
                
                // Files header
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                    Text("Files")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(panelState.selectedTab == .files ? .accentColor : .primary)
                .frame(maxWidth: .infinity)
                
                Divider()
                    .frame(height: 20)
                
                // Notes header
                HStack(spacing: 6) {
                    Image(systemName: "note.text")
                    Text("Notes")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(panelState.selectedTab == .notes ? .accentColor : .primary)
                .frame(maxWidth: .infinity)
                
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
                .padding(.leading, 12)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Three panels side by side with adjustable dividers
            ThreePanelSplitView(
                clipboardView: AnyView(ClipboardView().environmentObject(clipboardManager)),
                filesView: AnyView(FilesView().environmentObject(filesManager)),
                notesView: AnyView(NotesView().environmentObject(notesManager)),
                selectedTab: panelState.selectedTab
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow))
        .cornerRadius(12)
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

// Split view with three resizable panels
struct ThreePanelSplitView: NSViewRepresentable {
    let clipboardView: AnyView
    let filesView: AnyView
    let notesView: AnyView
    let selectedTab: PanelState.PanelTab
    
    class Coordinator: NSObject, NSSplitViewDelegate {
        func splitViewDidResizeSubviews(_ notification: Notification) {
            guard let splitView = notification.object as? NSSplitView else { return }
            
            // Save divider positions
            let positions = splitView.arrangedSubviews.map { $0.frame.width }
            UserDefaults.standard.set(positions, forKey: "TrayMe.DividerPositions")
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeNSView(context: Context) -> NSSplitView {
        let splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = context.coordinator
        
        // Create three hosting views
        let clipboardHosting = NSHostingView(rootView: clipboardView)
        let filesHosting = NSHostingView(rootView: filesView)
        let notesHosting = NSHostingView(rootView: notesView)
        
        // Add views to split view
        splitView.addArrangedSubview(clipboardHosting)
        splitView.addArrangedSubview(filesHosting)
        splitView.addArrangedSubview(notesHosting)
        
        // Restore saved positions or use equal proportions
        if let savedPositions = UserDefaults.standard.array(forKey: "TrayMe.DividerPositions") as? [CGFloat],
           savedPositions.count == 3 {
            // Restore saved widths
            DispatchQueue.main.async {
                for (index, width) in savedPositions.enumerated() {
                    if index < splitView.arrangedSubviews.count {
                        let subview = splitView.arrangedSubviews[index]
                        subview.widthAnchor.constraint(equalToConstant: width).isActive = false
                        splitView.setPosition(savedPositions.prefix(index + 1).reduce(0, +), ofDividerAt: index)
                    }
                }
            }
        }
        
        // Set equal proportions initially
        splitView.setHoldingPriority(.init(250), forSubviewAt: 0)
        splitView.setHoldingPriority(.init(250), forSubviewAt: 1)
        splitView.setHoldingPriority(.init(250), forSubviewAt: 2)
        
        return splitView
    }
    
    func updateNSView(_ nsView: NSSplitView, context: Context) {
        // Update background highlight based on selected tab
        for (index, subview) in nsView.arrangedSubviews.enumerated() {
            let shouldHighlight = (index == 0 && selectedTab == .clipboard) ||
                                  (index == 1 && selectedTab == .files) ||
                                  (index == 2 && selectedTab == .notes)
            
            if shouldHighlight {
                subview.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.05).cgColor
            } else {
                subview.layer?.backgroundColor = NSColor.clear.cgColor
            }
            subview.wantsLayer = true
        }
    }
}
