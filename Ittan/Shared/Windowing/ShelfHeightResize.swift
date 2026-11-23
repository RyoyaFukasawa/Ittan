import CoreGraphics

enum ShelfResizeHandleLayout {
    static let side: CGFloat = 28
    /// Transparent margin outside the shelf glass. The grip sits in this margin.
    static let gutter: CGFloat = 14

    static func windowSize(forGlass size: CGSize) -> CGSize {
        CGSize(width: size.width + gutter, height: size.height + gutter)
    }

    static func glassHeight(windowHeight: CGFloat) -> CGFloat {
        max(0, windowHeight - gutter)
    }

    /// The glass stays on the screen edge. The gutter is the inner side plus the bottom.
    static func glassFrame(in bounds: CGRect, edge: ShelfEdge, showsGutter: Bool) -> CGRect {
        guard showsGutter else { return bounds }
        let width = max(0, bounds.width - gutter)
        let height = max(0, bounds.height - gutter)
        let x = edge == .left ? bounds.minX : bounds.minX + gutter
        return CGRect(x: x, y: bounds.minY + gutter, width: width, height: height)
    }

    /// The hit target straddles the inner bottom corner, half over the glass and half in the gutter.
    static func frame(in bounds: CGRect, edge: ShelfEdge) -> CGRect {
        let x = edge == .left ? bounds.maxX - side : bounds.minX
        return CGRect(x: x, y: bounds.minY, width: side, height: side)
    }

    static func gutterFrames(in bounds: CGRect, edge: ShelfEdge) -> [CGRect] {
        let sideGutter = CGRect(
            x: edge == .left ? bounds.maxX - gutter : bounds.minX,
            y: bounds.minY,
            width: gutter,
            height: bounds.height
        )
        let bottomGutter = CGRect(
            x: bounds.minX,
            y: bounds.minY,
            width: bounds.width,
            height: gutter
        )
        return [sideGutter, bottomGutter]
    }
}

enum ShelfHeightResize {
    /// Keeps the shelf centered while the bottom grip follows the pointer.
    static func height(
        initialHeight: CGFloat,
        cursorDeltaY: CGFloat,
        minimumHeight: CGFloat,
        screenHeight: CGFloat
    ) -> CGFloat {
        let proposed = initialHeight - (cursorDeltaY * 2)
        let limit = max(screenHeight, 0)
        let lower = limit > 0 ? min(minimumHeight, limit) : minimumHeight
        let upper = limit > 0 ? max(limit, lower) : max(proposed, lower)
        return min(max(proposed, lower), upper)
    }

    static func snapped(
        proposedHeight: CGFloat,
        minimumHeight: CGFloat,
        maximumHeight: CGFloat,
        rowStep: CGFloat
    ) -> CGFloat {
        guard rowStep > 0 else { return min(max(proposedHeight, 0), max(maximumHeight, 0)) }
        let maximum = max(maximumHeight, 0)
        if maximum <= minimumHeight {
            return maximum > 0 ? maximum : minimumHeight
        }
        let clamped = min(max(proposedHeight, minimumHeight), maximum)
        let requestedSteps = ((clamped - minimumHeight) / rowStep).rounded()
        let maximumSteps = ((maximum - minimumHeight) / rowStep).rounded(.down)
        return minimumHeight + min(requestedSteps, maximumSteps) * rowStep
    }

    /// A drag that does not change the window, or that is blocked by a short screen,
    /// keeps a taller preferred height. An actual shrink replaces it.
    static func committedHeight(
        liveHeight: CGFloat,
        preferredHeight: CGFloat,
        dragStartHeight: CGFloat,
        minimumHeight: CGFloat,
        screenHeight: CGFloat,
        rowStep: CGFloat
    ) -> CGFloat {
        if abs(liveHeight - dragStartHeight) < 1 {
            return max(preferredHeight, minimumHeight)
        }
        let snapped = snapped(
            proposedHeight: liveHeight,
            minimumHeight: minimumHeight,
            maximumHeight: screenHeight,
            rowStep: rowStep
        )
        if liveHeight >= screenHeight - 1, preferredHeight > snapped {
            return preferredHeight
        }
        return max(snapped, minimumHeight)
    }
}
