import CoreGraphics

enum ShelfWindowDragHitPolicy {
    static func shouldMoveShelf(
        from point: CGPoint,
        interactiveFrames: [CGRect]
    ) -> Bool {
        !interactiveFrames.contains { $0.contains(point) }
    }
}
