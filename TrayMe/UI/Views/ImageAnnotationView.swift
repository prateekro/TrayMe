//
//  ImageAnnotationView.swift
//  TrayMe
//

import SwiftUI
import AppKit

// MARK: - Annotation Models
enum AnnotationTool: String, CaseIterable {
    case select = "Select"
    case draw = "Draw"
    case text = "Text"
    case arrow = "Arrow"
    case rectangle = "Rectangle"
    case circle = "Circle"
    case line = "Line"
    case highlight = "Highlight"
    case blur = "Blur"
    case eraser = "Eraser"
}

struct Annotation: Identifiable, Equatable {
    let id = UUID()
    let tool: AnnotationTool
    var points: [CGPoint]
    var text: String?
    var color: NSColor
    var lineWidth: CGFloat
    var isFilled: Bool
    var isFinalized: Bool
    
    static func == (lhs: Annotation, rhs: Annotation) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Canvas View
struct AnnotationCanvasView: NSViewRepresentable {
    @Binding var annotations: [Annotation]
    @Binding var currentAnnotation: Annotation?
    let tool: AnnotationTool
    let color: NSColor
    let lineWidth: CGFloat
    let baseImage: NSImage
    let onAnnotationAdded: () -> Void
    let onTextRequested: ((CGPoint) -> Void)?
    
    func makeNSView(context: Context) -> CanvasNSView {
        let view = CanvasNSView()
        view.delegate = context.coordinator
        view.baseImage = baseImage
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        
        // Enable mouse events
        view.translatesAutoresizingMaskIntoConstraints = false
        
        return view
    }
    
    func updateNSView(_ nsView: CanvasNSView, context: Context) {
        print("🔄 Canvas update - annotations: \(annotations.count), tool: \(tool)")
        nsView.annotations = annotations
        nsView.currentAnnotation = currentAnnotation
        nsView.tool = tool
        nsView.color = color
        nsView.lineWidth = lineWidth
        nsView.baseImage = baseImage
        nsView.needsDisplay = true
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CanvasDelegate {
        let parent: AnnotationCanvasView
        
        init(_ parent: AnnotationCanvasView) {
            self.parent = parent
        }
        
        func annotationStarted(_ annotation: Annotation) {
            print("📢 Coordinator: annotationStarted called")
            DispatchQueue.main.async {
                print("📢 Setting currentAnnotation")
                self.parent.currentAnnotation = annotation
            }
        }
        
        func annotationUpdated(_ annotation: Annotation) {
            DispatchQueue.main.async {
                self.parent.currentAnnotation = annotation
            }
        }
        
        func annotationFinalized(_ annotation: Annotation) {
            print("📢 Coordinator: annotationFinalized called")
            DispatchQueue.main.async {
                print("📢 Adding annotation to list, current count: \(self.parent.annotations.count)")
                self.parent.annotations.append(annotation)
                self.parent.currentAnnotation = nil
                print("📢 New count: \(self.parent.annotations.count)")
                self.parent.onAnnotationAdded()
            }
        }
        
        func requestTextInput(at point: CGPoint) {
            DispatchQueue.main.async {
                self.parent.onTextRequested?(point)
            }
        }
    }
}

protocol CanvasDelegate: AnyObject {
    func annotationStarted(_ annotation: Annotation)
    func annotationUpdated(_ annotation: Annotation)
    func annotationFinalized(_ annotation: Annotation)
    func requestTextInput(at point: CGPoint)
}

class CanvasNSView: NSView {
    weak var delegate: CanvasDelegate?
    var annotations: [Annotation] = []
    var currentAnnotation: Annotation?
    var tool: AnnotationTool = .draw
    var color: NSColor = .red
    var lineWidth: CGFloat = 3.0
    var baseImage: NSImage?
    
    private var startPoint: CGPoint?
    private var selectedAnnotationIndex: Int?
    private var dragOffset: CGPoint = .zero
    
    override var acceptsFirstResponder: Bool { true }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupTracking()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTracking()
    }
    
    private func setupTracking() {
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .inVisibleRect, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        // Remove old tracking areas
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        
        // Add new tracking area
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .inVisibleRect, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    override func keyDown(with event: NSEvent) {
        // Delete or Backspace key
        if event.keyCode == 51 || event.keyCode == 117 {
            if let selectedIndex = selectedAnnotationIndex {
                print("🗑️ Deleting annotation at index \(selectedIndex)")
                annotations.remove(at: selectedIndex)
                selectedAnnotationIndex = nil
                needsDisplay = true
                return
            }
        }
        super.keyDown(with: event)
    }
    
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        startPoint = point
        
        print("🖱️ Mouse Down at: \(point)")
        print("🎨 Current tool: \(tool)")
        print("🎨 Color: \(color), Line width: \(lineWidth)")
        
        // Handle special tools
        if tool == .text {
            delegate?.requestTextInput(at: point)
            return
        }
        
        if tool == .select {
            // Find annotation at point (reverse order to get topmost)
            selectedAnnotationIndex = nil
            for (index, annotation) in annotations.enumerated().reversed() {
                if hitTest(point: point, in: annotation) {
                    selectedAnnotationIndex = index
                    dragOffset = CGPoint(
                        x: point.x - annotation.points[0].x,
                        y: point.y - annotation.points[0].y
                    )
                    print("✅ Selected annotation \(index): \(annotation.tool)")
                    needsDisplay = true
                    return
                }
            }
            print("ℹ️ No annotation at point")
            needsDisplay = true
            return
        }
        
        let annotation = Annotation(
            tool: tool,
            points: [point],
            text: nil,
            color: color,
            lineWidth: lineWidth,
            isFilled: tool == .highlight || tool == .blur,
            isFinalized: false
        )
        
        print("✅ Annotation created: \(annotation)")
        
        delegate?.annotationStarted(annotation)
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        
        print("🖱️ Mouse Dragged to: \(point)")
        
        // Handle select tool - move annotation
        if tool == .select, let selectedIndex = selectedAnnotationIndex {
            var annotation = annotations[selectedIndex]
            let newOrigin = CGPoint(x: point.x - dragOffset.x, y: point.y - dragOffset.y)
            let delta = CGPoint(x: newOrigin.x - annotation.points[0].x, y: newOrigin.y - annotation.points[0].y)
            
            // Move all points by delta
            annotation.points = annotation.points.map { pt in
                CGPoint(x: pt.x + delta.x, y: pt.y + delta.y)
            }
            
            annotations[selectedIndex] = annotation
            print("🔄 Moved annotation to: \(newOrigin)")
            needsDisplay = true
            return
        }
        
        guard var annotation = currentAnnotation, let start = startPoint else { 
            print("❌ Mouse dragged but no current annotation or start point")
            return 
        }
        
        switch tool {
        case .draw, .eraser:
            annotation.points.append(point)
            print("✏️ Added point, total points: \(annotation.points.count)")
        case .line, .arrow:
            annotation.points = [start, point]
            print("📏 Line/Arrow updated")
        case .rectangle, .circle, .highlight, .blur:
            annotation.points = [start, point]
            print("⬜️ Shape updated")
        default:
            break
        }
        
        // CRITICAL FIX: Update currentAnnotation with the modified copy
        currentAnnotation = annotation
        delegate?.annotationUpdated(annotation)
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        guard var annotation = currentAnnotation else { 
            print("❌ Mouse up but no current annotation")
            return 
        }
        
        print("🖱️ Mouse Up - finalizing annotation with \(annotation.points.count) points")
        
        annotation.isFinalized = true
        delegate?.annotationFinalized(annotation)
        startPoint = nil
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        print("🎨 Drawing canvas - bounds: \(bounds)")
        print("📊 Annotations count: \(annotations.count), Current: \(currentAnnotation != nil ? "YES" : "NO")")
        
        guard let context = NSGraphicsContext.current?.cgContext else { 
            print("❌ No graphics context!")
            return 
        }
        
        // Clear the view first
        context.clear(bounds)
        
        // Draw base image
        if let image = baseImage {
            print("🖼️ Drawing base image: \(image.size)")
            image.draw(in: bounds)
        } else {
            print("❌ No base image!")
        }
        
        // Draw all finalized annotations ON TOP
        for (index, annotation) in annotations.enumerated() {
            print("✏️ Drawing annotation \(index): \(annotation.tool), points: \(annotation.points.count)")
            drawAnnotation(annotation)
            
            // Draw selection indicator
            if let selectedIndex = selectedAnnotationIndex, index == selectedIndex {
                drawSelectionIndicator(for: annotation, in: context)
            }
        }
        
        // Draw current annotation being created ON TOP
        if let current = currentAnnotation {
            print("✏️ Drawing CURRENT annotation: \(current.tool), points: \(current.points.count)")
            drawAnnotation(current)
        }
    }
    
    private func drawAnnotation(_ annotation: Annotation) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        context.saveGState()
        
        switch annotation.tool {
        case .draw:
            drawFreehand(annotation, in: context)
        case .line:
            drawLine(annotation, in: context)
        case .arrow:
            drawArrow(annotation, in: context)
        case .rectangle:
            drawRectangle(annotation, in: context)
        case .circle:
            drawCircle(annotation, in: context)
        case .highlight:
            drawHighlight(annotation, in: context)
        case .blur:
            drawBlur(annotation)
        case .eraser:
            drawEraser(annotation, in: context)
        case .text:
            drawText(annotation)
        default:
            break
        }
        
        context.restoreGState()
    }
    
    private func drawFreehand(_ annotation: Annotation, in context: CGContext) {
        guard annotation.points.count > 1 else { return }
        
        context.setStrokeColor(annotation.color.cgColor)
        context.setLineWidth(annotation.lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        // Use smooth path for better drawing
        let path = CGMutablePath()
        path.move(to: annotation.points[0])
        
        for i in 1..<annotation.points.count {
            path.addLine(to: annotation.points[i])
        }
        
        context.addPath(path)
        context.strokePath()
    }
    
    private func drawLine(_ annotation: Annotation, in context: CGContext) {
        guard annotation.points.count >= 2 else { return }
        
        context.setStrokeColor(annotation.color.cgColor)
        context.setLineWidth(annotation.lineWidth)
        context.setLineCap(.round)
        
        context.beginPath()
        context.move(to: annotation.points[0])
        context.addLine(to: annotation.points[1])
        context.strokePath()
    }
    
    private func drawArrow(_ annotation: Annotation, in context: CGContext) {
        guard annotation.points.count >= 2 else { return }
        
        let start = annotation.points[0]
        let end = annotation.points[1]
        
        // Draw line
        context.setStrokeColor(annotation.color.cgColor)
        context.setLineWidth(annotation.lineWidth)
        context.setLineCap(.round)
        
        context.beginPath()
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()
        
        // Draw arrowhead
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = 15
        let arrowAngle: CGFloat = .pi / 6
        
        let point1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let point2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )
        
        context.beginPath()
        context.move(to: point1)
        context.addLine(to: end)
        context.addLine(to: point2)
        context.strokePath()
    }
    
    private func drawRectangle(_ annotation: Annotation, in context: CGContext) {
        guard annotation.points.count >= 2 else { return }
        
        let rect = CGRect(
            x: min(annotation.points[0].x, annotation.points[1].x),
            y: min(annotation.points[0].y, annotation.points[1].y),
            width: abs(annotation.points[1].x - annotation.points[0].x),
            height: abs(annotation.points[1].y - annotation.points[0].y)
        )
        
        if annotation.isFilled {
            context.setFillColor(annotation.color.withAlphaComponent(0.3).cgColor)
            context.fill(rect)
        }
        
        context.setStrokeColor(annotation.color.cgColor)
        context.setLineWidth(annotation.lineWidth)
        context.stroke(rect)
    }
    
    private func drawCircle(_ annotation: Annotation, in context: CGContext) {
        guard annotation.points.count >= 2 else { return }
        
        let rect = CGRect(
            x: min(annotation.points[0].x, annotation.points[1].x),
            y: min(annotation.points[0].y, annotation.points[1].y),
            width: abs(annotation.points[1].x - annotation.points[0].x),
            height: abs(annotation.points[1].y - annotation.points[0].y)
        )
        
        if annotation.isFilled {
            context.setFillColor(annotation.color.withAlphaComponent(0.3).cgColor)
            context.fillEllipse(in: rect)
        }
        
        context.setStrokeColor(annotation.color.cgColor)
        context.setLineWidth(annotation.lineWidth)
        context.strokeEllipse(in: rect)
    }
    
    private func drawHighlight(_ annotation: Annotation, in context: CGContext) {
        guard annotation.points.count >= 2 else { return }
        
        let rect = CGRect(
            x: min(annotation.points[0].x, annotation.points[1].x),
            y: min(annotation.points[0].y, annotation.points[1].y),
            width: abs(annotation.points[1].x - annotation.points[0].x),
            height: abs(annotation.points[1].y - annotation.points[0].y)
        )
        
        context.setFillColor(annotation.color.withAlphaComponent(0.4).cgColor)
        context.fill(rect)
    }
    
    private func drawBlur(_ annotation: Annotation) {
        // Blur effect would require more complex CIFilter implementation
        // For now, draw a pixelated rectangle as placeholder
        guard annotation.points.count >= 2 else { return }
        
        let rect = NSRect(
            x: min(annotation.points[0].x, annotation.points[1].x),
            y: min(annotation.points[0].y, annotation.points[1].y),
            width: abs(annotation.points[1].x - annotation.points[0].x),
            height: abs(annotation.points[1].y - annotation.points[0].y)
        )
        
        NSColor.black.withAlphaComponent(0.5).setFill()
        rect.fill()
    }
    
    private func drawEraser(_ annotation: Annotation, in context: CGContext) {
        guard annotation.points.count > 1 else { return }
        
        context.setBlendMode(.clear)
        context.setLineWidth(annotation.lineWidth * 2)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        context.beginPath()
        context.move(to: annotation.points[0])
        for point in annotation.points.dropFirst() {
            context.addLine(to: point)
        }
        context.strokePath()
    }
    
    private func drawText(_ annotation: Annotation) {
        guard let text = annotation.text, !text.isEmpty,
              let point = annotation.points.first else { return }
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: annotation.color
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        attributedString.draw(at: point)
    }
    
    // MARK: - Selection Support
    
    private func hitTest(point: CGPoint, in annotation: Annotation) -> Bool {
        let tolerance: CGFloat = 10.0
        
        switch annotation.tool {
        case .text:
            guard let first = annotation.points.first else { return false }
            return abs(point.x - first.x) < tolerance * 5 && abs(point.y - first.y) < tolerance * 5
            
        case .draw, .eraser:
            // Check if point is near any segment of the path
            for i in 0..<annotation.points.count - 1 {
                let p1 = annotation.points[i]
                let p2 = annotation.points[i + 1]
                if distanceToLineSegment(point: point, p1: p1, p2: p2) < tolerance {
                    return true
                }
            }
            return false
            
        case .line, .arrow:
            guard annotation.points.count >= 2 else { return false }
            return distanceToLineSegment(point: point, p1: annotation.points[0], p2: annotation.points[1]) < tolerance
            
        case .rectangle, .highlight:
            guard annotation.points.count >= 2 else { return false }
            let rect = CGRect(
                x: min(annotation.points[0].x, annotation.points[1].x),
                y: min(annotation.points[0].y, annotation.points[1].y),
                width: abs(annotation.points[1].x - annotation.points[0].x),
                height: abs(annotation.points[1].y - annotation.points[0].y)
            )
            return rect.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
            
        case .circle:
            guard annotation.points.count >= 2 else { return false }
            let center = CGPoint(
                x: (annotation.points[0].x + annotation.points[1].x) / 2,
                y: (annotation.points[0].y + annotation.points[1].y) / 2
            )
            let radiusX = abs(annotation.points[1].x - annotation.points[0].x) / 2
            let radiusY = abs(annotation.points[1].y - annotation.points[0].y) / 2
            let dx = (point.x - center.x) / radiusX
            let dy = (point.y - center.y) / radiusY
            return sqrt(dx * dx + dy * dy) <= 1.0 + (tolerance / max(radiusX, radiusY))
            
        case .blur:
            guard annotation.points.count >= 2 else { return false }
            let rect = CGRect(
                x: min(annotation.points[0].x, annotation.points[1].x),
                y: min(annotation.points[0].y, annotation.points[1].y),
                width: abs(annotation.points[1].x - annotation.points[0].x),
                height: abs(annotation.points[1].y - annotation.points[0].y)
            )
            return rect.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
            
        case .select:
            return false
        }
    }
    
    private func distanceToLineSegment(point: CGPoint, p1: CGPoint, p2: CGPoint) -> CGFloat {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        
        if dx == 0 && dy == 0 {
            return sqrt(pow(point.x - p1.x, 2) + pow(point.y - p1.y, 2))
        }
        
        let t = max(0, min(1, ((point.x - p1.x) * dx + (point.y - p1.y) * dy) / (dx * dx + dy * dy)))
        let projection = CGPoint(x: p1.x + t * dx, y: p1.y + t * dy)
        
        return sqrt(pow(point.x - projection.x, 2) + pow(point.y - projection.y, 2))
    }
    
    private func drawSelectionIndicator(for annotation: Annotation, in context: CGContext) {
        context.saveGState()
        
        // Calculate bounding box
        guard !annotation.points.isEmpty else {
            context.restoreGState()
            return
        }
        
        var minX = annotation.points[0].x
        var maxX = annotation.points[0].x
        var minY = annotation.points[0].y
        var maxY = annotation.points[0].y
        
        for point in annotation.points {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        
        let padding: CGFloat = 8.0
        let selectionRect = CGRect(
            x: minX - padding,
            y: minY - padding,
            width: maxX - minX + 2 * padding,
            height: maxY - minY + 2 * padding
        )
        
        // Draw dashed border
        context.setStrokeColor(NSColor.systemBlue.cgColor)
        context.setLineWidth(2.0)
        context.setLineDash(phase: 0, lengths: [5, 5])
        context.stroke(selectionRect)
        
        // Draw corner handles
        let handleSize: CGFloat = 6.0
        let handles = [
            CGPoint(x: selectionRect.minX, y: selectionRect.minY),
            CGPoint(x: selectionRect.maxX, y: selectionRect.minY),
            CGPoint(x: selectionRect.minX, y: selectionRect.maxY),
            CGPoint(x: selectionRect.maxX, y: selectionRect.maxY)
        ]
        
        context.setFillColor(NSColor.systemBlue.cgColor)
        for handle in handles {
            let handleRect = CGRect(
                x: handle.x - handleSize / 2,
                y: handle.y - handleSize / 2,
                width: handleSize,
                height: handleSize
            )
            context.fill(handleRect)
        }
        
        context.restoreGState()
    }
}
