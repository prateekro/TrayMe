//
//  ImageAnnotationView.swift
//  TrayMe
//

import SwiftUI
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

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

    // Text-specific properties
    var fontSize: CGFloat
    var fontWeight: NSFont.Weight
    var isBold: Bool
    var isItalic: Bool

    init(tool: AnnotationTool, points: [CGPoint], text: String? = nil, color: NSColor,
         lineWidth: CGFloat, isFilled: Bool, isFinalized: Bool,
         fontSize: CGFloat = 16, fontWeight: NSFont.Weight = .regular,
         isBold: Bool = false, isItalic: Bool = false) {
        self.tool = tool
        self.points = points
        self.text = text
        self.color = color
        self.lineWidth = lineWidth
        self.isFilled = isFilled
        self.isFinalized = isFinalized
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.isBold = isBold
        self.isItalic = isItalic
    }

    static func == (lhs: Annotation, rhs: Annotation) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Canvas Delegate Protocol

protocol CanvasDelegate: AnyObject {
    func annotationStarted(_ annotation: Annotation)
    func annotationUpdated(_ annotation: Annotation)
    func annotationFinalized(_ annotation: Annotation)
    func annotationDiscarded()
    func annotationsDidChange(_ annotations: [Annotation])
    func requestTextInput(at point: CGPoint)
    func editTextAnnotation(at index: Int)
}

// MARK: - Canvas View (NSViewRepresentable)

struct AnnotationCanvasView: NSViewRepresentable {
    @Binding var annotations: [Annotation]
    @Binding var currentAnnotation: Annotation?
    let tool: AnnotationTool
    let color: NSColor
    let lineWidth: CGFloat
    let baseImage: NSImage
    let onAnnotationAdded: () -> Void
    let onTextRequested: ((CGPoint) -> Void)?
    let onTextEdit: ((Int) -> Void)?
    let fontSize: CGFloat
    let fontWeight: NSFont.Weight

    func makeNSView(context: Context) -> CanvasNSView {
        let view = CanvasNSView()
        view.delegate = context.coordinator
        view.baseImage = baseImage
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    func updateNSView(_ nsView: CanvasNSView, context: Context) {
        let annotationsChanged = nsView.annotations.count != annotations.count ||
            !zip(nsView.annotations, annotations).allSatisfy({ $0.id == $1.id })

        let imageChanged = nsView.baseImage !== baseImage

        let needsUpdate = annotationsChanged ||
            imageChanged ||
            nsView.tool != tool ||
            nsView.color != color ||
            nsView.lineWidth != lineWidth ||
            nsView.fontSize != fontSize ||
            nsView.fontWeight != fontWeight ||
            (currentAnnotation != nil) != (nsView.currentAnnotation != nil)

        guard needsUpdate else { return }

        if annotationsChanged || imageChanged {
            nsView.needsFullRedraw = true
        }

        nsView.annotations = annotations
        nsView.currentAnnotation = currentAnnotation
        nsView.tool = tool
        nsView.color = color
        nsView.lineWidth = lineWidth
        nsView.baseImage = baseImage
        nsView.fontSize = fontSize
        nsView.fontWeight = fontWeight

        nsView.validateSelection()
        nsView.updateCursorForTool()
        nsView.needsDisplay = true
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: Coordinator

    class Coordinator: NSObject, CanvasDelegate {
        let parent: AnnotationCanvasView

        init(_ parent: AnnotationCanvasView) {
            self.parent = parent
        }

        func annotationStarted(_ annotation: Annotation) {
            DispatchQueue.main.async {
                self.parent.currentAnnotation = annotation
            }
        }

        func annotationUpdated(_ annotation: Annotation) {
            DispatchQueue.main.async {
                self.parent.currentAnnotation = annotation
            }
        }

        func annotationFinalized(_ annotation: Annotation) {
            DispatchQueue.main.async {
                self.parent.annotations.append(annotation)
                self.parent.currentAnnotation = nil
                self.parent.onAnnotationAdded()
            }
        }

        func annotationDiscarded() {
            DispatchQueue.main.async {
                self.parent.currentAnnotation = nil
            }
        }

        func annotationsDidChange(_ annotations: [Annotation]) {
            DispatchQueue.main.async {
                self.parent.annotations = annotations
            }
        }

        func requestTextInput(at point: CGPoint) {
            DispatchQueue.main.async {
                self.parent.onTextRequested?(point)
            }
        }

        func editTextAnnotation(at index: Int) {
            DispatchQueue.main.async {
                self.parent.onTextEdit?(index)
            }
        }
    }
}

// MARK: - Canvas NSView

class CanvasNSView: NSView {
    weak var delegate: CanvasDelegate?
    var annotations: [Annotation] = []
    var currentAnnotation: Annotation?
    var tool: AnnotationTool = .draw
    var color: NSColor = .red
    var lineWidth: CGFloat = 3.0
    var baseImage: NSImage?
    var fontSize: CGFloat = 16
    var fontWeight: NSFont.Weight = .regular

    private var startPoint: CGPoint?
    private var selectedAnnotationIndex: Int?
    private var dragOffset: CGPoint = .zero
    private var isDraggingAnnotation: Bool = false

    // Performance optimization - cached rendering
    private var cachedImage: NSImage?
    var needsFullRedraw = true

    // Track bounds size to invalidate cache on resize
    private var lastBoundsSize: CGSize = .zero

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
            options: [.activeAlways, .mouseMoved, .inVisibleRect, .mouseEnteredAndExited, .cursorUpdate],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        for area in trackingAreas {
            removeTrackingArea(area)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .inVisibleRect, .mouseEnteredAndExited, .cursorUpdate],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    // MARK: - Cursor Management

    func updateCursorForTool() {
        window?.invalidateCursorRects(for: self)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        let cursor: NSCursor
        switch tool {
        case .select:
            cursor = .arrow
        case .draw:
            cursor = .crosshair
        case .text:
            cursor = .iBeam
        case .arrow, .line:
            cursor = .crosshair
        case .rectangle, .circle, .highlight, .blur:
            cursor = .crosshair
        case .eraser:
            cursor = .disappearingItem
        }
        addCursorRect(bounds, cursor: cursor)
    }

    // MARK: - Selection Validation

    func validateSelection() {
        if let index = selectedAnnotationIndex {
            if index >= annotations.count {
                selectedAnnotationIndex = nil
            }
        }
    }

    // MARK: - Keyboard Events

    override func keyDown(with event: NSEvent) {
        // Delete or Backspace key
        if event.keyCode == 51 || event.keyCode == 117 {
            if let selectedIndex = selectedAnnotationIndex, selectedIndex < annotations.count {
                annotations.remove(at: selectedIndex)
                selectedAnnotationIndex = nil
                needsFullRedraw = true
                needsDisplay = true
                delegate?.annotationsDidChange(annotations)
                return
            }
        }

        // Cmd+Z for undo
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "z" {
            if !annotations.isEmpty {
                annotations.removeLast()
                selectedAnnotationIndex = nil
                needsFullRedraw = true
                needsDisplay = true
                delegate?.annotationsDidChange(annotations)
                return
            }
        }

        // Escape to deselect
        if event.keyCode == 53 {
            if selectedAnnotationIndex != nil {
                selectedAnnotationIndex = nil
                needsFullRedraw = true
                needsDisplay = true
                return
            }
        }

        super.keyDown(with: event)
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        if window?.firstResponder !== self {
            window?.makeFirstResponder(self)
        }

        let point = convert(event.locationInWindow, from: nil)
        let clampedPoint = clampPointToBounds(point)
        startPoint = clampedPoint
        isDraggingAnnotation = false

        if tool == .text {
            delegate?.requestTextInput(at: clampedPoint)
            return
        }

        if tool == .select {
            if event.clickCount == 2 {
                for (index, annotation) in annotations.enumerated().reversed() {
                    if annotation.tool == .text && isPointInAnnotation(point: clampedPoint, annotation: annotation) {
                        delegate?.editTextAnnotation(at: index)
                        return
                    }
                }
            }

            selectedAnnotationIndex = nil
            for (index, annotation) in annotations.enumerated().reversed() {
                if isPointInAnnotation(point: clampedPoint, annotation: annotation) {
                    selectedAnnotationIndex = index
                    isDraggingAnnotation = true
                    dragOffset = CGPoint(
                        x: clampedPoint.x - annotation.points[0].x,
                        y: clampedPoint.y - annotation.points[0].y
                    )
                    needsFullRedraw = true
                    needsDisplay = true
                    return
                }
            }
            needsFullRedraw = true
            needsDisplay = true
            return
        }

        let annotation = Annotation(
            tool: tool,
            points: [clampedPoint],
            text: nil,
            color: color,
            lineWidth: lineWidth,
            isFilled: tool == .highlight || tool == .blur,
            isFinalized: false,
            fontSize: fontSize,
            fontWeight: fontWeight
        )

        delegate?.annotationStarted(annotation)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let clampedPoint = clampPointToBounds(point)

        if tool == .select, isDraggingAnnotation,
           let selectedIndex = selectedAnnotationIndex,
           selectedIndex < annotations.count {
            var annotation = annotations[selectedIndex]
            let newOrigin = CGPoint(
                x: clampedPoint.x - dragOffset.x,
                y: clampedPoint.y - dragOffset.y
            )
            let delta = CGPoint(
                x: newOrigin.x - annotation.points[0].x,
                y: newOrigin.y - annotation.points[0].y
            )

            annotation.points = annotation.points.map { pt in
                CGPoint(x: pt.x + delta.x, y: pt.y + delta.y)
            }

            annotations[selectedIndex] = annotation
            needsFullRedraw = true
            needsDisplay = true
            return
        }

        guard var annotation = currentAnnotation, let start = startPoint else {
            return
        }

        switch tool {
        case .draw, .eraser:
            annotation.points.append(clampedPoint)
        case .line, .arrow:
            annotation.points = [start, clampedPoint]
        case .rectangle, .circle, .highlight, .blur:
            annotation.points = [start, clampedPoint]
        default:
            break
        }

        currentAnnotation = annotation
        delegate?.annotationUpdated(annotation)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if tool == .select && isDraggingAnnotation {
            isDraggingAnnotation = false
            delegate?.annotationsDidChange(annotations)
            needsFullRedraw = true
            needsDisplay = true
            return
        }

        guard var annotation = currentAnnotation else {
            return
        }

        let isDegenerate: Bool
        switch annotation.tool {
        case .draw, .eraser:
            isDegenerate = annotation.points.count < 2
        case .line, .arrow:
            if annotation.points.count < 2 {
                isDegenerate = true
            } else {
                let dx = annotation.points[1].x - annotation.points[0].x
                let dy = annotation.points[1].y - annotation.points[0].y
                isDegenerate = sqrt(dx * dx + dy * dy) < 2.0
            }
        case .rectangle, .circle, .highlight, .blur:
            if annotation.points.count < 2 {
                isDegenerate = true
            } else {
                let w = abs(annotation.points[1].x - annotation.points[0].x)
                let h = abs(annotation.points[1].y - annotation.points[0].y)
                isDegenerate = w < 2.0 && h < 2.0
            }
        case .text, .select:
            isDegenerate = false
        }

        if isDegenerate {
            currentAnnotation = nil
            delegate?.annotationDiscarded()
            startPoint = nil
            return
        }

        annotation.isFinalized = true
        delegate?.annotationFinalized(annotation)
        startPoint = nil
        needsFullRedraw = true
        needsDisplay = true
    }

    // MARK: - Point Clamping

    private func clampPointToBounds(_ point: CGPoint) -> CGPoint {
        return CGPoint(
            x: max(0, min(bounds.width, point.x)),
            y: max(0, min(bounds.height, point.y))
        )
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        context.clear(bounds)

        if lastBoundsSize != bounds.size {
            lastBoundsSize = bounds.size
            needsFullRedraw = true
        }

        if needsFullRedraw || cachedImage == nil {
            cachedImage = renderBaseWithAnnotations()
            needsFullRedraw = false
        }

        cachedImage?.draw(in: bounds)

        if let current = currentAnnotation {
            drawAnnotation(current)
        }

        if let selectedIndex = selectedAnnotationIndex, selectedIndex < annotations.count {
            drawSelectionIndicator(for: annotations[selectedIndex], in: context)
        }
    }

    private func renderBaseWithAnnotations() -> NSImage? {
        guard let baseImage = baseImage else { return nil }
        guard bounds.width > 0 && bounds.height > 0 else { return nil }

        let image = NSImage(size: bounds.size)
        image.lockFocus()

        guard NSGraphicsContext.current?.cgContext != nil else {
            image.unlockFocus()
            return nil
        }

        baseImage.draw(in: bounds)

        for annotation in annotations {
            drawAnnotation(annotation)
        }

        image.unlockFocus()
        return image
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
        case .select:
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

        let path = CGMutablePath()
        path.move(to: annotation.points[0])

        if annotation.points.count == 2 {
            path.addLine(to: annotation.points[1])
        } else {
            for i in 1..<annotation.points.count {
                let currentPoint = annotation.points[i]
                let previousPoint = annotation.points[i - 1]
                let midPoint = CGPoint(
                    x: (previousPoint.x + currentPoint.x) / 2,
                    y: (previousPoint.y + currentPoint.y) / 2
                )

                if i == 1 {
                    path.addLine(to: midPoint)
                } else {
                    path.addQuadCurve(to: midPoint, control: previousPoint)
                }
            }
            if let lastPoint = annotation.points.last {
                path.addLine(to: lastPoint)
            }
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

        context.setStrokeColor(annotation.color.cgColor)
        context.setLineWidth(annotation.lineWidth)
        context.setLineCap(.round)

        context.beginPath()
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()

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
    }

    private func drawRectangle(_ annotation: Annotation, in context: CGContext) {
        guard annotation.points.count >= 2 else { return }

        let rect = CGRect(
            x: min(annotation.points[0].x, annotation.points[1].x),
            y: min(annotation.points[0].y, annotation.points[1].y),
            width: abs(annotation.points[1].x - annotation.points[0].x),
            height: abs(annotation.points[1].y - annotation.points[0].y)
        )

        guard rect.width > 0 && rect.height > 0 else { return }

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

        guard rect.width > 0 && rect.height > 0 else { return }

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

        guard rect.width > 0 && rect.height > 0 else { return }

        context.setFillColor(annotation.color.withAlphaComponent(0.4).cgColor)
        context.fill(rect)
    }

    private func drawBlur(_ annotation: Annotation) {
        guard annotation.points.count >= 2,
              let baseImage = baseImage else { return }

        let rect = NSRect(
            x: min(annotation.points[0].x, annotation.points[1].x),
            y: min(annotation.points[0].y, annotation.points[1].y),
            width: abs(annotation.points[1].x - annotation.points[0].x),
            height: abs(annotation.points[1].y - annotation.points[0].y)
        )

        guard rect.width > 0 && rect.height > 0 else { return }

        if let cgImage = baseImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let imageSize = baseImage.size
            let viewSize = bounds.size

            guard viewSize.width > 0 && viewSize.height > 0 else {
                NSColor.black.withAlphaComponent(0.5).setFill()
                rect.fill()
                return
            }

            let scaleX = imageSize.width / viewSize.width
            let scaleY = imageSize.height / viewSize.height

            let imageRect = CGRect(
                x: rect.origin.x * scaleX,
                y: rect.origin.y * scaleY,
                width: rect.width * scaleX,
                height: rect.height * scaleY
            )

            let clampedRect = imageRect.intersection(CGRect(origin: .zero, size: imageSize))
            guard clampedRect.width > 0 && clampedRect.height > 0 else {
                NSColor.black.withAlphaComponent(0.5).setFill()
                rect.fill()
                return
            }

            let ciImage = CIImage(cgImage: cgImage)
            let croppedCI = ciImage.cropped(to: clampedRect)

            let blurFilter = CIFilter(name: "CIGaussianBlur")
            blurFilter?.setValue(croppedCI, forKey: kCIInputImageKey)
            blurFilter?.setValue(10.0, forKey: kCIInputRadiusKey)

            if let outputImage = blurFilter?.outputImage {
                let ciContext = CIContext()
                let finalCropped = outputImage.cropped(to: clampedRect)
                if let blurredCG = ciContext.createCGImage(finalCropped, from: clampedRect) {
                    let blurredNS = NSImage(cgImage: blurredCG, size: rect.size)
                    blurredNS.draw(in: rect)
                    return
                }
            }
        }

        NSColor.black.withAlphaComponent(0.5).setFill()
        rect.fill()
    }

    private func drawEraser(_ annotation: Annotation, in context: CGContext) {
        guard annotation.points.count > 1 else { return }

        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(annotation.lineWidth * 2)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setBlendMode(.normal)

        context.beginPath()
        context.move(to: annotation.points[0])
        for point in annotation.points.dropFirst() {
            context.addLine(to: point)
        }
        context.strokePath()
    }

    private func drawText(_ annotation: Annotation) {
        guard let text = annotation.text, !text.isEmpty,
              let point = annotation.points.first else {
            return
        }

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

        let textSize = attributedString.size()
        guard textSize.width > 0 && textSize.height > 0 else { return }

        let backgroundRect = CGRect(
            x: point.x - 2,
            y: point.y - 2,
            width: textSize.width + 4,
            height: textSize.height + 4
        )

        NSColor.black.withAlphaComponent(0.1).setFill()
        NSBezierPath(roundedRect: backgroundRect, xRadius: 3, yRadius: 3).fill()

        attributedString.draw(at: point)
    }

    // MARK: - Selection Support

    private func isPointInAnnotation(point: CGPoint, annotation: Annotation) -> Bool {
        let tolerance: CGFloat = 10.0

        switch annotation.tool {
        case .text:
            guard let first = annotation.points.first,
                  let text = annotation.text, !text.isEmpty else { return false }
            let font = NSFont.systemFont(ofSize: annotation.fontSize, weight: annotation.fontWeight)
            let attributes: [NSAttributedString.Key: Any] = [.font: font]
            let textSize = NSAttributedString(string: text, attributes: attributes).size()
            guard textSize.width > 0 && textSize.height > 0 else { return false }
            let textRect = CGRect(x: first.x, y: first.y, width: textSize.width, height: textSize.height)
            return textRect.insetBy(dx: -tolerance, dy: -tolerance).contains(point)

        case .draw, .eraser:
            guard annotation.points.count >= 2 else {
                if let only = annotation.points.first {
                    let dx = point.x - only.x
                    let dy = point.y - only.y
                    return sqrt(dx * dx + dy * dy) < tolerance
                }
                return false
            }
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

            guard radiusX > 0.001 && radiusY > 0.001 else {
                let dx = point.x - center.x
                let dy = point.y - center.y
                return sqrt(dx * dx + dy * dy) < tolerance
            }

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

        if annotation.tool == .text,
           let text = annotation.text, !text.isEmpty,
           let first = annotation.points.first {
            let font = NSFont.systemFont(ofSize: annotation.fontSize, weight: annotation.fontWeight)
            let attributes: [NSAttributedString.Key: Any] = [.font: font]
            let textSize = NSAttributedString(string: text, attributes: attributes).size()
            maxX = max(maxX, first.x + textSize.width)
            maxY = max(maxY, first.y + textSize.height)
        }

        let padding: CGFloat = 8.0
        let selectionRect = CGRect(
            x: minX - padding,
            y: minY - padding,
            width: maxX - minX + 2 * padding,
            height: maxY - minY + 2 * padding
        )

        context.setStrokeColor(NSColor.systemBlue.cgColor)
        context.setLineWidth(2.0)
        context.setLineDash(phase: 0, lengths: [5, 5])
        context.stroke(selectionRect)

        let handleSize: CGFloat = 6.0
        let handles = [
            CGPoint(x: selectionRect.minX, y: selectionRect.minY),
            CGPoint(x: selectionRect.maxX, y: selectionRect.minY),
            CGPoint(x: selectionRect.minX, y: selectionRect.maxY),
            CGPoint(x: selectionRect.maxX, y: selectionRect.maxY)
        ]

        context.setFillColor(NSColor.systemBlue.cgColor)
        context.setLineDash(phase: 0, lengths: [])
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
