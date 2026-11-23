import CoreGraphics

enum ShelfAppearance {
    /// The tallest shelf that can sit in the usable area of a screen.
    /// A missing or empty visible frame falls back to the physical screen.
    static func maximumHeight(screenFrame: CGRect, visibleFrame: CGRect?) -> CGFloat {
        let screenHeight = max(screenFrame.height, 0)
        guard let visibleFrame else { return screenHeight }
        let usable = visibleFrame.intersection(screenFrame)
        guard usable.height > 1 else { return screenHeight }
        return min(usable.height, screenHeight)
    }

    /// Pins the shelf to the left or right edge of a screen.
    /// `normalizedMidY` slides it along that edge. A missing value centers it.
    /// When a visible frame is given, a shelf that would pass under the menu bar or Dock
    /// shrinks and shifts into that usable area.
    static func frame(
        edge: ShelfEdge,
        dimensions: ShelfDimensions,
        screenFrame: CGRect,
        visibleFrame: CGRect? = nil,
        normalizedMidY: CGFloat? = nil
    ) -> CGRect {
        let width = min(max(dimensions.width, 0), max(screenFrame.width, 0))
        let height = min(
            max(dimensions.height, 0),
            maximumHeight(screenFrame: screenFrame, visibleFrame: visibleFrame)
        )
        let x = edge == .left ? screenFrame.minX : screenFrame.maxX - width
        let anchor = screenFrame.minY + (normalizedMidY ?? 0.5) * screenFrame.height
        var y = min(
            max(anchor - height / 2, screenFrame.minY),
            max(screenFrame.minY, screenFrame.maxY - height)
        )
        if let visible = visibleFrame?.intersection(screenFrame), visible.height > 1 {
            if y < visible.minY {
                y = visible.minY
            }
            if y + height > visible.maxY {
                y = visible.maxY - height
            }
            y = min(max(y, screenFrame.minY), max(screenFrame.minY, screenFrame.maxY - height))
        }
        return CGRect(x: x, y: y, width: width, height: height)
    }

    static func placement(
        edge: ShelfEdge,
        dimensions: ShelfDimensions,
        screenID: String?,
        screenFrame: CGRect,
        normalizedMidY: CGFloat? = nil
    ) -> ShelfPlacement {
        guard screenFrame.width > 0, screenFrame.height > 0 else {
            return .floating(
                screenID: screenID,
                normalizedFrame: CGRect(x: 0.8, y: 0.25, width: 0.2, height: 0.5)
            )
        }

        return .floating(
            screenID: screenID,
            normalizedFrame: ShelfPlacementGeometry.normalizedFrame(
                frame(
                    edge: edge,
                    dimensions: dimensions,
                    screenFrame: screenFrame,
                    normalizedMidY: normalizedMidY
                ),
                in: screenFrame
            )
        )
    }
}
