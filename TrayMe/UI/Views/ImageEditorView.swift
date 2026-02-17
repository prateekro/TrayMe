//
//  ImageEditorView.swift
//  TrayMe
//

import SwiftUI
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Metal

enum EditorMode {
    case edit
    case annotate
}

struct ImageEditorView: View {
    @EnvironmentObject var manager: ClipboardManager
    @State private var editedImage: NSImage
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    @State private var flipHorizontal: Bool = false
    @State private var flipVertical: Bool = false
    @State private var showingSaveAlert: Bool = false
    
    // Mode
    @State private var editorMode: EditorMode = .edit
    
    // Crop state
    @State private var isCropping: Bool = false
    @State private var cropRect: CGRect = .zero
    
    // Resize state
    @State private var showingResizeSheet: Bool = false
    @State private var newWidth: String = ""
    @State private var newHeight: String = ""
    @State private var maintainAspectRatio: Bool = true
    
    // Filter/Adjustment state
    @State private var brightness: Double = 0
    @State private var contrast: Double = 1.0
    @State private var saturation: Double = 1.0
    @State private var selectedFilter: ImageFilter = .none
    @State private var showingFilters: Bool = false
    
    // Annotation state
    @State private var annotations: [Annotation] = []
    @State private var currentAnnotation: Annotation?
    @State private var selectedTool: AnnotationTool = .draw
    @State private var annotationColor: NSColor = .red
    @State private var annotationLineWidth: CGFloat = 3.0
    @State private var showingTextInput: Bool = false
    @State private var textInputPosition: CGPoint = .zero
    @State private var textInputValue: String = ""
    @State private var selectedAnnotationIndex: Int?
    @State private var editingTextIndex: Int?
    
    // Text styling
    @State private var textFontSize: CGFloat = 24
    @State private var textFontWeight: NSFont.Weight = .medium
    @State private var textIsBold: Bool = false
    @State private var textIsItalic: Bool = false
    
    // Additional features
    @State private var showingHistory: Bool = false
    @State private var editHistory: [NSImage] = []
    @State private var historyIndex: Int = -1
    
    // Copy feedback
    @State private var showCopyFeedback: Bool = false
    
    // Cache the filtered image to avoid recomputation
    @State private var cachedFilteredImage: NSImage?
    @State private var lastFilterParams: FilterParams?
    
    let originalItem: ClipboardItem
    let onClose: () -> Void
    
    enum ImageFilter: String, CaseIterable {
        case none = "None"
        case sepia = "Sepia"
        case noir = "Noir"
        case chrome = "Chrome"
        case fade = "Fade"
        case instant = "Instant"
        case mono = "Mono"
        case tonal = "Tonal"
        case transfer = "Transfer"
    }
    
    // Track filter parameters to detect changes
    private struct FilterParams: Equatable {
        let brightness: Double
        let contrast: Double
        let saturation: Double
        let filter: ImageFilter
        let imageSize: CGSize
    }
    
    init(item: ClipboardItem, onClose: @escaping () -> Void) {
        self.originalItem = item
        self.onClose = onClose
        let originalImage = item.image ?? NSImage()
        _editedImage = State(initialValue: originalImage)
        _newWidth = State(initialValue: String(Int(originalImage.size.width)))
        _newHeight = State(initialValue: String(Int(originalImage.size.height)))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Image Editor")
                    .font(.system(size: 14, weight: .semibold))
                
                Spacer()
                
                // Mode switcher
                Picker("Mode", selection: $editorMode) {
                    Text("Edit").tag(EditorMode.edit)
                    Text("Annotate").tag(EditorMode.annotate)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                
                Spacer()
                
                Button("Reset All") {
                    resetAll()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Image preview/canvas
            ZStack {
                Color(NSColor.controlBackgroundColor)
                
                GeometryReader { geometry in
                    if editorMode == .annotate {
                        // Annotation canvas - centered with proper sizing
                        HStack {
                            Spacer()
                            VStack {
                                Spacer()
                                AnnotationCanvasView(
                                    annotations: $annotations,
                                    currentAnnotation: $currentAnnotation,
                                    tool: selectedTool,
                                    color: annotationColor,
                                    lineWidth: annotationLineWidth,
                                    baseImage: currentFilteredImage,
                                    onAnnotationAdded: {},
                                    onTextRequested: { point in
                                        textInputPosition = point
                                        editingTextIndex = nil
                                        textInputValue = ""
                                        showingTextInput = true
                                    },
                                    onTextEdit: { index in
                                        guard index >= 0 && index < annotations.count else { return }
                                        editingTextIndex = index
                                        let annotation = annotations[index]
                                        if let text = annotation.text {
                                            textInputValue = text
                                            textInputPosition = annotation.points.first ?? .zero
                                            textFontSize = annotation.fontSize
                                            textFontWeight = annotation.fontWeight
                                            textIsBold = annotation.isBold
                                            textIsItalic = annotation.isItalic
                                            annotationColor = annotation.color
                                            showingTextInput = true
                                        }
                                    },
                                    fontSize: textFontSize,
                                    fontWeight: textFontWeight
                                )
                                .aspectRatio(currentFilteredImage.size, contentMode: .fit)
                                .frame(maxWidth: geometry.size.width * 0.9, maxHeight: geometry.size.height * 0.9)
                                .border(Color.gray.opacity(0.3), width: 1)
                                Spacer()
                            }
                            Spacer()
                        }
                        
                        // Text input overlay
                        if showingTextInput {
                            VStack {
                                Spacer()
                                VStack(spacing: 16) {
                                    Text(editingTextIndex != nil ? "Edit Text" : "Add Text")
                                        .font(.headline)
                                    
                                    TextField("Enter text", text: $textInputValue)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 350)
                                    
                                    // Font size slider
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Font Size: \(Int(textFontSize))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Slider(value: $textFontSize, in: 12...72, step: 2)
                                            .frame(width: 350)
                                    }
                                    
                                    // Style toggles
                                    HStack(spacing: 20) {
                                        Toggle("Bold", isOn: $textIsBold)
                                            .toggleStyle(.button)
                                        
                                        Toggle("Italic", isOn: $textIsItalic)
                                            .toggleStyle(.button)
                                        
                                        // Color picker
                                        ColorPicker("Color", selection: Binding(
                                            get: { Color(annotationColor) },
                                            set: { annotationColor = NSColor($0) }
                                        ))
                                        .labelsHidden()
                                        .frame(width: 60)
                                    }
                                    
                                    // Preview
                                    Text(textInputValue.isEmpty ? "Preview" : textInputValue)
                                        .font(.system(size: textFontSize, weight: textIsBold ? .bold : .regular))
                                        .italic(textIsItalic)
                                        .foregroundColor(Color(annotationColor))
                                        .padding(8)
                                        .background(Color.black.opacity(0.05))
                                        .cornerRadius(4)
                                        .frame(width: 350, alignment: .leading)
                                    
                                    HStack(spacing: 12) {
                                        Button("Cancel") {
                                            showingTextInput = false
                                            textInputValue = ""
                                            editingTextIndex = nil
                                        }
                                        .buttonStyle(.bordered)
                                        
                                        Button(editingTextIndex != nil ? "Update" : "Add") {
                                            addTextAnnotation()
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .disabled(textInputValue.isEmpty)
                                    }
                                }
                                .padding(20)
                                .background(Color(NSColor.windowBackgroundColor))
                                .cornerRadius(8)
                                .shadow(radius: 10)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black.opacity(0.3))
                        }
                    } else {
                        // Regular edit preview
                        ScrollView([.horizontal, .vertical]) {
                            Image(nsImage: currentFilteredImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: geometry.size.width * 0.9)
                                .scaleEffect(scale)
                                .rotationEffect(.degrees(rotation))
                                .scaleEffect(x: flipHorizontal ? -1 : 1, y: flipVertical ? -1 : 1)
                                .padding()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            
            Divider()
            
            // Editing tools
            if editorMode == .annotate {
                annotationControls
            } else {
                editControls
            }
            
            Divider()
            
            // Action buttons
            ZStack {
                HStack(spacing: 12) {
                    Button("Copy") {
                        copyTransformedImage()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Save as New") {
                        saveAsNewItem()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button(action: {
                        manager.toggleFavorite(originalItem)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: originalItem.isFavorite ? "star.fill" : "star")
                            Text(originalItem.isFavorite ? "Favorited" : "Favorite")
                        }
                        .font(.system(size: 11))
                        .foregroundColor(originalItem.isFavorite ? .yellow : .secondary)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        manager.deleteItem(originalItem)
                        onClose()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("Delete")
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                // Copy feedback overlay
                if showCopyFeedback {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Copied to clipboard!")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .shadow(radius: 4)
                    .transition(.opacity.combined(with: .scale))
                }
            }
        }
        .alert("Image Saved", isPresented: $showingSaveAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The edited image has been saved as a new clipboard item.")
        }
        .sheet(isPresented: $showingResizeSheet) {
            ResizeSheet(
                width: $newWidth,
                height: $newHeight,
                maintainAspectRatio: $maintainAspectRatio,
                originalSize: editedImage.size,
                onResize: {
                    applyResize()
                    showingResizeSheet = false
                },
                onCancel: { showingResizeSheet = false }
            )
        }
        .onChange(of: brightness) { _, _ in invalidateFilterCache() }
        .onChange(of: contrast) { _, _ in invalidateFilterCache() }
        .onChange(of: saturation) { _, _ in invalidateFilterCache() }
        .onChange(of: selectedFilter) { _, _ in invalidateFilterCache() }
        .onChange(of: editedImage.size) { _, _ in invalidateFilterCache() }
    }
    
    // MARK: - Cached Filtered Image
    
    private var currentFilteredImage: NSImage {
        let params = FilterParams(
            brightness: brightness,
            contrast: contrast,
            saturation: saturation,
            filter: selectedFilter,
            imageSize: editedImage.size
        )
        
        if let cached = cachedFilteredImage, lastFilterParams == params {
            return cached
        }
        
        let result = computeFilteredImage()
        DispatchQueue.main.async {
            self.cachedFilteredImage = result
            self.lastFilterParams = params
        }
        return result
    }
    
    private func invalidateFilterCache() {
        cachedFilteredImage = nil
        lastFilterParams = nil
    }
    
    // MARK: - Edit Controls
    private var editControls: some View {
        VStack(spacing: 0) {
            // Tool categories
            HStack(spacing: 4) {
                ToolTabButton(title: "Transform", icon: "rotate.left", isSelected: !showingFilters) {
                    showingFilters = false
                }
                ToolTabButton(title: "Adjust", icon: "slider.horizontal.3", isSelected: showingFilters) {
                    showingFilters = true
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            Divider()
                .padding(.top, 8)
            
            // Tool controls
            if showingFilters {
                adjustmentControls
            } else {
                transformControls
            }
        }
        .padding(.bottom)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Annotation Controls
    private var annotationControls: some View {
        VStack(spacing: 12) {
            // Drawing tools
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AnnotationTool.allCases, id: \.self) { tool in
                        AnnotationToolButton(
                            tool: tool,
                            isSelected: selectedTool == tool,
                            action: { selectedTool = tool }
                        )
                    }
                }
                .padding(.horizontal)
            }
            
            // Tool hint
            if selectedTool == .select {
                Text("Click to select, drag to move, Delete key to remove, double-click text to edit")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            } else if selectedTool == .text {
                Text("Click to add text with custom size, style, and color")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            Divider()
            
            // Color and size controls
            HStack(spacing: 16) {
                // Color picker
                HStack(spacing: 8) {
                    Text("Color:")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    ColorPicker("", selection: Binding(
                        get: { Color(annotationColor) },
                        set: { annotationColor = NSColor($0) }
                    ))
                    .labelsHidden()
                    .frame(width: 40)
                    
                    // Common colors
                    ForEach([NSColor.red, .systemBlue, .systemGreen, .systemYellow, .black, .white], id: \.self) { color in
                        Button(action: { annotationColor = color }) {
                            Circle()
                                .fill(Color(color))
                                .frame(width: 20, height: 20)
                                .overlay(
                                    Circle()
                                        .stroke(annotationColor == color ? Color.accentColor : Color.clear, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Divider()
                    .frame(height: 30)
                
                // Line width
                HStack(spacing: 8) {
                    Text("Size:")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Slider(value: $annotationLineWidth, in: 1...10, step: 1)
                        .frame(width: 100)
                    
                    Text("\(Int(annotationLineWidth))")
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 20)
                }
                
                Divider()
                    .frame(height: 30)
                
                // Undo
                Button(action: undoLastAnnotation) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Undo")
                    }
                    .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .disabled(annotations.isEmpty)
                
                Button(action: clearAnnotations) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("Clear All")
                    }
                    .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                .disabled(annotations.isEmpty)
                
                Spacer()
                
                // Quick actions
                Button(action: { saveSnapshot() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "camera")
                        Text("Snapshot")
                    }
                    .font(.system(size: 11))
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Transform Controls
    private var transformControls: some View {
        VStack(spacing: 12) {
            // Transform buttons
            HStack(spacing: 12) {
                Button(action: { rotation -= 90 }) {
                    VStack(spacing: 4) {
                        Image(systemName: "rotate.left")
                        Text("Rotate L")
                            .font(.system(size: 10))
                    }
                }
                .buttonStyle(.bordered)
                
                Button(action: { rotation += 90 }) {
                    VStack(spacing: 4) {
                        Image(systemName: "rotate.right")
                        Text("Rotate R")
                            .font(.system(size: 10))
                    }
                }
                .buttonStyle(.bordered)
                
                Button(action: { flipHorizontal.toggle() }) {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.left.and.right")
                        Text("Flip H")
                            .font(.system(size: 10))
                    }
                }
                .buttonStyle(.bordered)
                
                Button(action: { flipVertical.toggle() }) {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.up.and.down")
                        Text("Flip V")
                            .font(.system(size: 10))
                    }
                }
                .buttonStyle(.bordered)
            }
            
            // Crop and Resize
            HStack(spacing: 12) {
                Button(action: { applyCrop() }) {
                    VStack(spacing: 4) {
                        Image(systemName: "crop")
                        Text("Crop 1:1")
                            .font(.system(size: 10))
                    }
                }
                .buttonStyle(.bordered)
                
                Button(action: { applyCrop(aspectRatio: 16/9) }) {
                    VStack(spacing: 4) {
                        Image(systemName: "crop")
                        Text("Crop 16:9")
                            .font(.system(size: 10))
                    }
                }
                .buttonStyle(.bordered)
                
                Button(action: { applyCrop(aspectRatio: 4/3) }) {
                    VStack(spacing: 4) {
                        Image(systemName: "crop")
                        Text("Crop 4:3")
                            .font(.system(size: 10))
                    }
                }
                .buttonStyle(.bordered)
                
                Button(action: { showingResizeSheet = true }) {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                        Text("Resize")
                            .font(.system(size: 10))
                    }
                }
                .buttonStyle(.bordered)
            }
            
            // Zoom slider
            HStack {
                Text("Zoom:")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Slider(value: $scale, in: 0.5...3.0, step: 0.1)
                    .frame(width: 150)
                
                Text("\(Int(scale * 100))%")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(width: 40)
            }
        }
        .padding()
    }
    
    // MARK: - Adjustment Controls
    private var adjustmentControls: some View {
        VStack(spacing: 12) {
            // Filter presets
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ImageFilter.allCases, id: \.self) { filter in
                        Button(action: { selectedFilter = filter }) {
                            Text(filter.rawValue)
                                .font(.system(size: 11))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedFilter == filter ? Color.accentColor : Color.secondary.opacity(0.2))
                                .foregroundColor(selectedFilter == filter ? .white : .primary)
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Adjustment sliders
            VStack(spacing: 8) {
                AdjustmentSlider(
                    title: "Brightness",
                    value: $brightness,
                    range: -0.5...0.5,
                    icon: "sun.max"
                )
                
                AdjustmentSlider(
                    title: "Contrast",
                    value: $contrast,
                    range: 0.5...2.0,
                    icon: "circle.lefthalf.filled"
                )
                
                AdjustmentSlider(
                    title: "Saturation",
                    value: $saturation,
                    range: 0.0...2.0,
                    icon: "paintpalette"
                )
            }
            
            Divider()
            
            // Quick presets
            HStack(spacing: 8) {
                Text("Quick:")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Button("B&W") { applyQuickEdit(edit: .grayscale) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                
                Button("High Contrast") { applyQuickEdit(edit: .highContrast) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                
                Button("Vintage") { applyQuickEdit(edit: .vintage) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                
                Button("Sharpen") { applyQuickEdit(edit: .sharpen) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding()
    }
    
    // MARK: - Helper Functions
    private func resetAll() {
        rotation = 0
        scale = 1.0
        flipHorizontal = false
        flipVertical = false
        brightness = 0
        contrast = 1.0
        saturation = 1.0
        selectedFilter = .none
        editedImage = originalItem.image ?? NSImage()
        annotations.removeAll()
        currentAnnotation = nil
        editingTextIndex = nil
        textInputValue = ""
        showingTextInput = false
        invalidateFilterCache()
    }
    
    private func addTextAnnotation() {
        guard !textInputValue.isEmpty else {
            showingTextInput = false
            editingTextIndex = nil
            return
        }
        
        if let editingIndex = editingTextIndex, editingIndex >= 0 && editingIndex < annotations.count {
            // Update existing annotation
            annotations[editingIndex].text = textInputValue
            annotations[editingIndex].color = annotationColor
            annotations[editingIndex].fontSize = textFontSize
            annotations[editingIndex].fontWeight = textIsBold ? .bold : textFontWeight
            annotations[editingIndex].isBold = textIsBold
            annotations[editingIndex].isItalic = textIsItalic
            editingTextIndex = nil
        } else {
            // Create new annotation
            let annotation = Annotation(
                tool: .text,
                points: [textInputPosition],
                text: textInputValue,
                color: annotationColor,
                lineWidth: annotationLineWidth,
                isFilled: false,
                isFinalized: true,
                fontSize: textFontSize,
                fontWeight: textIsBold ? .bold : textFontWeight,
                isBold: textIsBold,
                isItalic: textIsItalic
            )
            annotations.append(annotation)
        }
        
        showingTextInput = false
        textInputValue = ""
    }
    
    private func undoLastAnnotation() {
        guard !annotations.isEmpty else { return }
        annotations.removeLast()
    }
    
    private func clearAnnotations() {
        annotations.removeAll()
        currentAnnotation = nil
    }
    
    private func saveSnapshot() {
        // Save current state to history
        let snapshot = currentFilteredImage
        if !annotations.isEmpty {
            let withAnnotations = renderAnnotationsOnImage(snapshot)
            editHistory.append(withAnnotations)
        } else {
            editHistory.append(snapshot)
        }
        historyIndex = editHistory.count - 1
    }
    
    private func applyQuickEdit(edit: QuickEdit) {
        switch edit {
        case .grayscale:
            saturation = 0
        case .highContrast:
            contrast = 1.5
        case .vintage:
            selectedFilter = .sepia
            brightness = -0.1
        case .sharpen:
            contrast = 1.3
        case .soften:
            brightness = 0.1
            saturation = 0.8
        }
    }
    
    enum QuickEdit {
        case grayscale, highContrast, vintage, sharpen, soften
    }
    
    // MARK: - Performance Optimized CIContext
    private static let sharedCIContext: CIContext = {
        // Use Metal for GPU acceleration
        if let device = MTLCreateSystemDefaultDevice() {
            return CIContext(mtlDevice: device, options: [
                .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                .cacheIntermediates: true
            ])
        }
        // Fallback to CPU
        return CIContext(options: [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            .useSoftwareRenderer: false
        ])
    }()
    
    private func computeFilteredImage() -> NSImage {
        guard let cgImage = editedImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return editedImage
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        let context = Self.sharedCIContext
        
        // Apply adjustments — always apply colorControls so saturation-only changes work
        var outputImage = ciImage
        
        if brightness != 0 || contrast != 1.0 || saturation != 1.0 {
            let filter = CIFilter.colorControls()
            filter.inputImage = outputImage
            filter.brightness = Float(brightness)
            filter.contrast = Float(contrast)
            filter.saturation = Float(saturation)
            outputImage = filter.outputImage ?? outputImage
        }
        
        // Apply selected filter
        switch selectedFilter {
        case .none:
            break
        case .sepia:
            let filter = CIFilter.sepiaTone()
            filter.inputImage = outputImage
            filter.intensity = 0.8
            outputImage = filter.outputImage ?? outputImage
        case .noir:
            let filter = CIFilter.photoEffectNoir()
            filter.inputImage = outputImage
            outputImage = filter.outputImage ?? outputImage
        case .chrome:
            let filter = CIFilter.photoEffectChrome()
            filter.inputImage = outputImage
            outputImage = filter.outputImage ?? outputImage
        case .fade:
            let filter = CIFilter.photoEffectFade()
            filter.inputImage = outputImage
            outputImage = filter.outputImage ?? outputImage
        case .instant:
            let filter = CIFilter.photoEffectInstant()
            filter.inputImage = outputImage
            outputImage = filter.outputImage ?? outputImage
        case .mono:
            let filter = CIFilter.photoEffectMono()
            filter.inputImage = outputImage
            outputImage = filter.outputImage ?? outputImage
        case .tonal:
            let filter = CIFilter.photoEffectTonal()
            filter.inputImage = outputImage
            outputImage = filter.outputImage ?? outputImage
        case .transfer:
            let filter = CIFilter.photoEffectTransfer()
            filter.inputImage = outputImage
            outputImage = filter.outputImage ?? outputImage
        }
        
        // Convert back to NSImage
        guard let outputCGImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return editedImage
        }
        
        return NSImage(cgImage: outputCGImage, size: editedImage.size)
    }
    
    private func applyTransformations() -> NSImage {
        let sourceImage = currentFilteredImage
        
        // If we have annotations, render them onto the image
        let imageWithAnnotations: NSImage
        if !annotations.isEmpty {
            imageWithAnnotations = renderAnnotationsOnImage(sourceImage)
        } else {
            imageWithAnnotations = sourceImage
        }
        
        let size = imageWithAnnotations.size
        guard size.width > 0 && size.height > 0 else { return imageWithAnnotations }
        
        // Calculate new size based on rotation
        let radians = rotation * .pi / 180
        let isRotated90or270 = Int(rotation) % 180 != 0
        let newWidth = isRotated90or270 ? size.height : size.width
        let newHeight = isRotated90or270 ? size.width : size.height
        
        let newSize = NSSize(width: newWidth, height: newHeight)
        let newImage = NSImage(size: newSize)
        
        newImage.lockFocus()
        defer { newImage.unlockFocus() }
        
        let ctx = NSGraphicsContext.current?.cgContext
        
        // Apply transformations
        ctx?.translateBy(x: newWidth / 2, y: newHeight / 2)
        ctx?.rotate(by: radians)
        ctx?.scaleBy(x: flipHorizontal ? -1 : 1, y: flipVertical ? -1 : 1)
        
        // Draw image
        imageWithAnnotations.draw(
            at: NSPoint(x: -size.width / 2, y: -size.height / 2),
            from: NSRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1.0
        )
        
        return newImage
    }
    
    private func renderAnnotationsOnImage(_ image: NSImage) -> NSImage {
        let newImage = NSImage(size: image.size)
        newImage.lockFocus()
        
        // Draw base image
        image.draw(at: .zero, from: NSRect(origin: .zero, size: image.size), operation: .copy, fraction: 1.0)
        
        // Draw annotations
        guard let context = NSGraphicsContext.current?.cgContext else {
            newImage.unlockFocus()
            return newImage
        }
        
        for annotation in annotations {
            renderAnnotation(annotation, in: context, imageSize: image.size)
        }
        
        newImage.unlockFocus()
        return newImage
    }
    
    private func renderAnnotation(_ annotation: Annotation, in context: CGContext, imageSize: NSSize? = nil) {
        context.saveGState()
        
        switch annotation.tool {
        case .draw:
            guard annotation.points.count > 1 else { break }
            context.setStrokeColor(annotation.color.cgColor)
            context.setLineWidth(annotation.lineWidth)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.beginPath()
            context.move(to: annotation.points[0])
            for point in annotation.points.dropFirst() {
                context.addLine(to: point)
            }
            context.strokePath()
            
        case .line:
            guard annotation.points.count >= 2 else { break }
            context.setStrokeColor(annotation.color.cgColor)
            context.setLineWidth(annotation.lineWidth)
            context.setLineCap(.round)
            context.beginPath()
            context.move(to: annotation.points[0])
            context.addLine(to: annotation.points[1])
            context.strokePath()
            
        case .arrow:
            guard annotation.points.count >= 2 else { break }
            let start = annotation.points[0]
            let end = annotation.points[1]
            
            context.setStrokeColor(annotation.color.cgColor)
            context.setLineWidth(annotation.lineWidth)
            context.setLineCap(.round)
            
            // Draw line
            context.beginPath()
            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()
            
            // Draw arrowhead
            let angle = atan2(end.y - start.y, end.x - start.x)
            let arrowLength: CGFloat = max(15, annotation.lineWidth * 5)
            let arrowAngle: CGFloat = .pi / 6
            
            let point1 = CGPoint(
                x: end.x - arrowLength * cos(angle - arrowAngle),
                y: end.y - arrowLength * sin(angle - arrowAngle)
            )
            let point2 = CGPoint(
                x: end.x - arrowLength * cos(angle + arrowAngle),
                y: end.y - arrowLength * sin(angle + arrowAngle)
            )
            
            context.setFillColor(annotation.color.cgColor)
            context.beginPath()
            context.move(to: point1)
            context.addLine(to: end)
            context.addLine(to: point2)
            context.closePath()
            context.fillPath()
            
        case .rectangle:
            guard annotation.points.count >= 2 else { break }
            let rect = CGRect(
                x: min(annotation.points[0].x, annotation.points[1].x),
                y: min(annotation.points[0].y, annotation.points[1].y),
                width: abs(annotation.points[1].x - annotation.points[0].x),
                height: abs(annotation.points[1].y - annotation.points[0].y)
            )
            guard rect.width > 0 && rect.height > 0 else { break }
            
            if annotation.isFilled {
                context.setFillColor(annotation.color.withAlphaComponent(0.3).cgColor)
                context.fill(rect)
            }
            
            context.setStrokeColor(annotation.color.cgColor)
            context.setLineWidth(annotation.lineWidth)
            context.stroke(rect)
            
        case .circle:
            guard annotation.points.count >= 2 else { break }
            let rect = CGRect(
                x: min(annotation.points[0].x, annotation.points[1].x),
                y: min(annotation.points[0].y, annotation.points[1].y),
                width: abs(annotation.points[1].x - annotation.points[0].x),
                height: abs(annotation.points[1].y - annotation.points[0].y)
            )
            guard rect.width > 0 && rect.height > 0 else { break }
            
            if annotation.isFilled {
                context.setFillColor(annotation.color.withAlphaComponent(0.3).cgColor)
                context.fillEllipse(in: rect)
            }
            
            context.setStrokeColor(annotation.color.cgColor)
            context.setLineWidth(annotation.lineWidth)
            context.strokeEllipse(in: rect)
            
        case .highlight:
            guard annotation.points.count >= 2 else { break }
            let rect = CGRect(
                x: min(annotation.points[0].x, annotation.points[1].x),
                y: min(annotation.points[0].y, annotation.points[1].y),
                width: abs(annotation.points[1].x - annotation.points[0].x),
                height: abs(annotation.points[1].y - annotation.points[0].y)
            )
            guard rect.width > 0 && rect.height > 0 else { break }
            context.setFillColor(annotation.color.withAlphaComponent(0.4).cgColor)
            context.fill(rect)
            
        case .blur:
            guard annotation.points.count >= 2 else { break }
            let rect = NSRect(
                x: min(annotation.points[0].x, annotation.points[1].x),
                y: min(annotation.points[0].y, annotation.points[1].y),
                width: abs(annotation.points[1].x - annotation.points[0].x),
                height: abs(annotation.points[1].y - annotation.points[0].y)
            )
            guard rect.width > 0 && rect.height > 0 else { break }
            context.setFillColor(NSColor.black.withAlphaComponent(0.7).cgColor)
            context.fill(rect)
            
        case .eraser:
            guard annotation.points.count > 1 else { break }
            context.setStrokeColor(NSColor.white.cgColor)
            context.setLineWidth(annotation.lineWidth * 2)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.beginPath()
            context.move(to: annotation.points[0])
            for point in annotation.points.dropFirst() {
                context.addLine(to: point)
            }
            context.strokePath()
            
        case .text:
            if let text = annotation.text, !text.isEmpty, let point = annotation.points.first {
                // Use the annotation's actual font properties
                var font: NSFont
                if annotation.isBold && annotation.isItalic {
                    font = NSFont.systemFont(ofSize: annotation.fontSize, weight: .bold)
                    let fontManager = NSFontManager.shared
                    font = fontManager.convert(font, toHaveTrait: [.boldFontMask, .italicFontMask])
                } else if annotation.isBold {
                    font = NSFont.systemFont(ofSize: annotation.fontSize, weight: .bold)
                } else if annotation.isItalic {
                    font = NSFont.systemFont(ofSize: annotation.fontSize, weight: annotation.fontWeight)
                    let fontManager = NSFontManager.shared
                    font = fontManager.convert(font, toHaveTrait: .italicFontMask)
                } else {
                    font = NSFont.systemFont(ofSize: annotation.fontSize, weight: annotation.fontWeight)
                }
                
                let shadow = NSShadow()
                shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
                shadow.shadowOffset = NSSize(width: 1, height: -1)
                shadow.shadowBlurRadius = 2
                
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: annotation.color,
                    .shadow: shadow
                ]
                let attributedString = NSAttributedString(string: text, attributes: attributes)
                attributedString.draw(at: point)
            }
            
        case .select:
            break
        }
        
        context.restoreGState()
    }
    
    private func applyCrop(aspectRatio: CGFloat? = nil) {
        let size = editedImage.size
        guard size.width > 0 && size.height > 0 else { return }
        
        let targetRatio = aspectRatio ?? 1.0 // Default to 1:1
        
        var cropWidth: CGFloat
        var cropHeight: CGFloat
        
        if size.width / size.height > targetRatio {
            // Image is wider, crop width
            cropHeight = size.height
            cropWidth = cropHeight * targetRatio
        } else {
            // Image is taller, crop height
            cropWidth = size.width
            cropHeight = cropWidth / targetRatio
        }
        
        let x = (size.width - cropWidth) / 2
        let y = (size.height - cropHeight) / 2
        let cropRect = NSRect(x: x, y: y, width: cropWidth, height: cropHeight)
        
        let croppedImage = NSImage(size: NSSize(width: cropWidth, height: cropHeight))
        croppedImage.lockFocus()
        editedImage.draw(
            in: NSRect(x: 0, y: 0, width: cropWidth, height: cropHeight),
            from: cropRect,
            operation: .copy,
            fraction: 1.0
        )
        croppedImage.unlockFocus()
        
        editedImage = croppedImage
        newWidth = String(Int(cropWidth))
        newHeight = String(Int(cropHeight))
        invalidateFilterCache()
    }
    
    private func applyResize() {
        guard let width = Double(newWidth), let height = Double(newHeight), width > 0, height > 0 else {
            return
        }
        
        // Clamp to reasonable maximum to avoid memory issues
        let maxDimension: Double = 10000
        let clampedWidth = min(width, maxDimension)
        let clampedHeight = min(height, maxDimension)
        
        let newSize = NSSize(width: clampedWidth, height: clampedHeight)
        let resizedImage = NSImage(size: newSize)
        
        resizedImage.lockFocus()
        editedImage.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: editedImage.size),
            operation: .copy,
            fraction: 1.0
        )
        resizedImage.unlockFocus()
        
        editedImage = resizedImage
        invalidateFilterCache()
    }
    
    private func copyTransformedImage() {
        let transformed = applyTransformations()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([transformed])
        
        // Update ClipboardManager's changeCount so it doesn't re-capture this as a new item
        manager.changeCount = pasteboard.changeCount
        
        // Show feedback
        withAnimation(.easeInOut(duration: 0.3)) {
            showCopyFeedback = true
        }
        
        // Hide feedback after delay
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation(.easeInOut(duration: 0.3)) {
                showCopyFeedback = false
            }
        }
    }
    
    private func saveAsNewItem() {
        let transformed = applyTransformations()
        manager.addImageItem(image: transformed)
        showingSaveAlert = true
    }
}

// MARK: - Supporting Views
struct AnnotationToolButton: View {
    let tool: AnnotationTool
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: iconName(for: tool))
                    .font(.system(size: 14))
                Text(tool.rawValue)
                    .font(.system(size: 9))
            }
            .frame(width: 60, height: 50)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.2))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
    
    private func iconName(for tool: AnnotationTool) -> String {
        switch tool {
        case .select: return "arrow.up.left.and.arrow.down.right"
        case .draw: return "pencil"
        case .text: return "textformat"
        case .arrow: return "arrow.right"
        case .rectangle: return "rectangle"
        case .circle: return "circle"
        case .line: return "line.diagonal"
        case .highlight: return "highlighter"
        case .blur: return "eye.slash"
        case .eraser: return "eraser"
        }
    }
}

struct ToolTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.clear)
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

struct AdjustmentSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Slider(value: $value, in: range)
                .frame(width: 200)
            
            Text(String(format: "%.2f", value))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 45, alignment: .trailing)
            
            Button(action: {
                // Reset to default
                if title == "Brightness" { value = 0 }
                else if title == "Contrast" { value = 1.0 }
                else if title == "Saturation" { value = 1.0 }
            }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

struct ResizeSheet: View {
    @Binding var width: String
    @Binding var height: String
    @Binding var maintainAspectRatio: Bool
    let originalSize: NSSize
    let onResize: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Resize Image")
                .font(.system(size: 16, weight: .semibold))
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Width:")
                        .frame(width: 80, alignment: .leading)
                    TextField("Width", text: $width)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .onChange(of: width) { _, newValue in
                            if maintainAspectRatio, let w = Double(newValue), originalSize.height > 0 {
                                let aspectRatio = originalSize.width / originalSize.height
                                height = String(Int(w / aspectRatio))
                            }
                        }
                    Text("px")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Height:")
                        .frame(width: 80, alignment: .leading)
                    TextField("Height", text: $height)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .onChange(of: height) { _, newValue in
                            if maintainAspectRatio, let h = Double(newValue), originalSize.height > 0 {
                                let aspectRatio = originalSize.width / originalSize.height
                                width = String(Int(h * aspectRatio))
                            }
                        }
                    Text("px")
                        .foregroundColor(.secondary)
                }
                
                Toggle("Maintain aspect ratio", isOn: $maintainAspectRatio)
                    .font(.system(size: 12))
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            Text("Original: \(Int(originalSize.width)) × \(Int(originalSize.height))")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                
                Button("Resize") {
                    onResize()
                }
                .buttonStyle(.borderedProminent)
                .disabled({
                    guard let w = Double(width), let h = Double(height) else { return true }
                    return w <= 0 || h <= 0
                }())
            }
        }
        .padding()
        .frame(width: 350)
    }
}

// MARK: - Array Safe Access Extension
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
