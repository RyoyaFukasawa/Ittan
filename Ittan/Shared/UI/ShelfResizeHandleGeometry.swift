import CoreGraphics

enum ShelfResizeHandleGeometry {
    struct Curve: Equatable {
        let start: CGPoint
        let control1: CGPoint
        let control2: CGPoint
        let end: CGPoint
    }

    /// The Stage Manager corner arc. A right-edge shelf mirrors it to the left corner.
    static func curve(in bounds: CGRect, edge: ShelfEdge) -> Curve {
        let right = Curve(
            start: CGPoint(x: bounds.maxX - 19, y: bounds.minY + 5),
            control1: CGPoint(x: bounds.maxX - 11, y: bounds.minY + 5),
            control2: CGPoint(x: bounds.maxX - 5, y: bounds.minY + 11),
            end: CGPoint(x: bounds.maxX - 5, y: bounds.minY + 19)
        )
        guard edge == .right else { return right }
        func mirror(_ point: CGPoint) -> CGPoint {
            CGPoint(x: bounds.minX + bounds.maxX - point.x, y: point.y)
        }
        return Curve(
            start: mirror(right.start),
            control1: mirror(right.control1),
            control2: mirror(right.control2),
            end: mirror(right.end)
        )
    }
}
