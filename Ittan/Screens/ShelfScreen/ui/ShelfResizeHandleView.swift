import AppKit

@MainActor
final class ShelfResizeHandleView: NSView {
    var edge: ShelfEdge = .right {
        didSet {
            needsDisplay = true
            window?.invalidateCursorRects(for: self)
        }
    }
    var onResizeBegan: (() -> Void)?
    var onResizeChanged: ((CGPoint) -> Void)?
    var onResizeEnded: (() -> Void)?

    private var trackingArea: NSTrackingArea?
    private var isHovered = false {
        didSet { if oldValue != isHovered { needsDisplay = true } }
    }
    private var isDragging = false {
        didSet {
            guard oldValue != isDragging else { return }
            needsDisplay = true
            window?.invalidateCursorRects(for: self)
        }
    }

    override var isFlipped: Bool { false }
    override var mouseDownCanMoveWindow: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("ShelfResizeHandleView is created in code")
    }

    override func updateTrackingAreas() {
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited, .cursorUpdate],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
        super.updateTrackingAreas()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHiddenOrHasHiddenAncestor else { return nil }
        return bounds.contains(convert(point, from: superview)) ? self : nil
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: resizeCursor)
    }

    override func cursorUpdate(with event: NSEvent) {
        resizeCursor.set()
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        resizeCursor.set()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        if !isDragging { NSCursor.arrow.set() }
    }

    override func mouseDown(with event: NSEvent) {
        guard !isHidden else { return }
        isDragging = true
        resizeCursor.set()
        onResizeBegan?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        onResizeChanged?(globalCursorPoint(for: event))
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        isDragging = false
        onResizeEnded?()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let opacity: CGFloat = isDragging ? 1 : (isHovered ? 0.92 : 0.7)
        NSColor.labelColor.withAlphaComponent(opacity).setStroke()

        let curve = ShelfResizeHandleGeometry.curve(in: bounds, edge: edge)
        let path = NSBezierPath()
        path.move(to: curve.start)
        path.curve(to: curve.end, controlPoint1: curve.control1, controlPoint2: curve.control2)
        path.lineWidth = 3
        path.lineCapStyle = .round
        path.stroke()
    }

    private var resizeCursor: NSCursor {
        if isDragging {
            let position: NSCursor.FrameResizePosition = edge == .left ? .bottomRight : .bottomLeft
            return .frameResize(position: position, directions: .outward)
        }
        return .pointingHand
    }

    private func globalCursorPoint(for event: NSEvent) -> CGPoint {
        guard let window = event.window else { return NSEvent.mouseLocation }
        return window.convertPoint(toScreen: event.locationInWindow)
    }
}
