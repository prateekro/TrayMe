//
//  ImageEditorView.swift
//  TrayMe
//

import SwiftUI
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

struct ImageEditorView: View {
    @EnvironmentObject var manager: ClipboardManager
    @State private var editedImage: NSImage
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    @State private var flipHorizontal: Bool = false
    @State private var flipVertical: Bool = false
    @State private var showingSaveAlert: Bool = false
    
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
            
            // Image preview with transformations
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: applyFiltersToImage())
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
            
            Divider()
            
            // Editing tools tabs
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
            
            Divider()
            
            // Action buttons
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
        }
        .frame(width: 600, height: 700)
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
    }
    
    private func applyFiltersToImage() -> NSImage {
        guard let cgImage = editedImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return editedImage
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        let context = CIContext()
        
        // Apply adjustments
        var outputImage = ciImage
        
        // Brightness and Contrast
        if brightness != 0 || contrast != 1.0 {
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
        let sourceImage = applyFiltersToImage()
        let size = sourceImage.size
        
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
        sourceImage.draw(
            at: NSPoint(x: -size.width / 2, y: -size.height / 2),
            from: NSRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1.0
        )
        
        return newImage
    }
    
    private func applyCrop(aspectRatio: CGFloat? = nil) {
        let size = editedImage.size
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
    }
    
    private func applyResize() {
        guard let width = Double(newWidth), let height = Double(newHeight), width > 0, height > 0 else {
            return
        }
        
        let newSize = NSSize(width: width, height: height)
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
    }
    
    private func copyTransformedImage() {
        let transformed = applyTransformations()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([transformed])
    }
    
    private func saveAsNewItem() {
        let transformed = applyTransformations()
        manager.addImageItem(image: transformed)
        showingSaveAlert = true
    }
}

// MARK: - Supporting Views
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
                            if maintainAspectRatio, let w = Double(newValue) {
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
                            if maintainAspectRatio, let h = Double(newValue) {
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
            }
        }
        .padding()
        .frame(width: 350)
    }
}
