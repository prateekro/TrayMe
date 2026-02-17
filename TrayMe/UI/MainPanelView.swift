//
//  MainPanelView.swift
//  TrayMe
//

import SwiftUI
import Combine

class PanelState: ObservableObject {
    @Published var selectedTab: PanelTab = .clipboard
    
    enum PanelTab: CaseIterable {
        case clipboard, files, notes
        
        var title: String {
            switch self {
            case .clipboard: return "Clipboard"
            case .files: return "Files"
            case .notes: return "Notes"
            }
        }
        
        var icon: String {
            switch self {
            case .clipboard: return "doc.on.clipboard.fill"
            case .files: return "folder.fill"
            case .notes: return "note.text"
            }
        }
        
        var inactiveIcon: String {
            switch self {
            case .clipboard: return "doc.on.clipboard"
            case .files: return "folder"
            case .notes: return "note.text"
            }
        }
    }
}

struct MainPanelView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @EnvironmentObject var filesManager: FilesManager
    @EnvironmentObject var notesManager: NotesManager
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var panelState: PanelState
    
    @Environment(\.openSettings) private var openSettings
    @State private var hoveredTab: PanelState.PanelTab?
    
    var body: some View {
        VStack(spacing: 0) {
            // Top navigation bar
            HStack(spacing: 2) {
                ForEach(PanelState.PanelTab.allCases, id: \.self) { tab in
                    let isSelected = panelState.selectedTab == tab
                    let isHovered = hoveredTab == tab
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            panelState.selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isSelected ? tab.icon : tab.inactiveIcon)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                                .contentTransition(.symbolEffect(.replace))
                            
                            Text(tab.title)
                                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                                .foregroundStyle(isSelected ? .primary : .secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(
                                    isSelected
                                    ? Color.accentColor.opacity(0.12)
                                    : (isHovered ? Color.primary.opacity(0.04) : Color.clear)
                                )
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .onHover { h in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            hoveredTab = h ? tab : nil
                        }
                    }
                    
                    if tab != PanelState.PanelTab.allCases.last {
                        Spacer()
                    }
                }
                
                Spacer()
                
                // Settings button
                Button {
                    if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                        appDelegate.mainPanel?.hide()
                    }
                    openSettings()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.primary.opacity(0.05))
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            
            // Thin separator with gradient
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, Color.primary.opacity(0.1), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
            
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
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
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
        for (index, subview) in nsView.arrangedSubviews.enumerated() {
            let shouldHighlight = (index == 0 && selectedTab == .clipboard) ||
                                  (index == 1 && selectedTab == .files) ||
                                  (index == 2 && selectedTab == .notes)
            
            subview.wantsLayer = true
            if shouldHighlight {
                subview.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.04).cgColor
            } else {
                subview.layer?.backgroundColor = NSColor.clear.cgColor
            }
        }
    }
}
