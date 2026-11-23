import CoreGraphics

enum ShelfCenterSnap {
    /// How close a vertical drag must come before it sticks to the screen center.
    /// The shelf stays there until the pointer moves farther than this.
    static let threshold: CGFloat = 6

    struct Decision: Equatable {
        let midY: CGFloat
        let isSnapped: Bool
    }

    static func decide(
        proposedMidY: CGFloat,
        centerMidY: CGFloat,
        threshold: CGFloat = Self.threshold
    ) -> Decision {
        guard abs(proposedMidY - centerMidY) <= threshold else {
            return Decision(midY: proposedMidY, isSnapped: false)
        }
        return Decision(midY: centerMidY, isSnapped: true)
    }

    /// A one-pixel horizontal line across the screen, centered on `midY`.
    static func guideFrame(screenFrame: CGRect, midY: CGFloat, scale: CGFloat) -> CGRect {
        let resolvedScale = scale > 0 ? scale : 1
        let thickness = 1 / resolvedScale
        let y = (midY * resolvedScale).rounded(.down) / resolvedScale
        return CGRect(
            x: screenFrame.minX,
            y: y,
            width: max(screenFrame.width, 0),
            height: thickness
        )
    }
}
