import Foundation

enum ShelfPlacementGeometry {
    static func placementAfterResize(
        _ placement: ShelfPlacement,
        frame: CGRect,
        screenID: String?,
        screenFrame: CGRect
    ) -> ShelfPlacement {
        switch placement {
        case .floating:
            return .floating(
                screenID: screenID,
                normalizedFrame: normalizedFrame(frame, in: screenFrame)
            )

        case let .docked(_, edge, _, _, order):
            return .docked(
                screenID: screenID,
                edge: edge,
                normalizedMidY: (frame.midY - screenFrame.minY) / screenFrame.height,
                isCollapsed: false,
                order: order
            )
        }
    }

    static func normalizedFrame(_ frame: CGRect, in screenFrame: CGRect) -> CGRect {
        guard screenFrame.width > 0, screenFrame.height > 0 else { return .zero }

        return CGRect(
            x: (frame.minX - screenFrame.minX) / screenFrame.width,
            y: (frame.minY - screenFrame.minY) / screenFrame.height,
            width: frame.width / screenFrame.width,
            height: frame.height / screenFrame.height
        )
    }

    static func restoredFrame(_ normalizedFrame: CGRect, in screenFrame: CGRect) -> CGRect {
        CGRect(
            x: screenFrame.minX + normalizedFrame.minX * screenFrame.width,
            y: screenFrame.minY + normalizedFrame.minY * screenFrame.height,
            width: normalizedFrame.width * screenFrame.width,
            height: normalizedFrame.height * screenFrame.height
        )
    }

    static func restoredFrame(
        _ normalizedFrame: CGRect,
        dimensions: ShelfDimensions,
        in screenFrame: CGRect
    ) -> CGRect {
        let dimensions = clampedDimensions(dimensions, in: screenFrame)
        let restoredOrigin = CGPoint(
            x: screenFrame.minX + normalizedFrame.minX * screenFrame.width,
            y: screenFrame.minY + normalizedFrame.minY * screenFrame.height
        )
        let origin = CGPoint(
            x: min(
                max(restoredOrigin.x, screenFrame.minX),
                screenFrame.maxX - dimensions.width
            ),
            y: min(
                max(restoredOrigin.y, screenFrame.minY),
                screenFrame.maxY - dimensions.height
            )
        )
        return CGRect(origin: origin, size: dimensions.size)
    }

    static func clampedDimensions(
        _ dimensions: ShelfDimensions,
        in screenFrame: CGRect
    ) -> ShelfDimensions {
        ShelfDimensions(
            width: min(
                max(dimensions.width, ShelfDimensions.minimum.width),
                max(0, screenFrame.width)
            ),
            height: min(
                max(dimensions.height, ShelfDimensions.minimum.height),
                max(0, screenFrame.height)
            )
        )
    }

    static func dockCandidate(
        for frame: CGRect,
        screenFrame: CGRect,
        threshold: CGFloat
    ) -> ShelfEdge? {
        let leftDistance = abs(frame.minX - screenFrame.minX)
        let rightDistance = abs(frame.maxX - screenFrame.maxX)
        let nearestDistance = min(leftDistance, rightDistance)

        guard nearestDistance <= max(0, threshold) else { return nil }
        return leftDistance <= rightDistance ? .left : .right
    }

    static func resolveDockSlots(
        _ requests: [ShelfDockRequest],
        screenFrame: CGRect,
        spacing: CGFloat
    ) -> [ShelfDockResolution]? {
        guard requests.allSatisfy({ $0.height >= 0 }) else { return nil }
        guard !requests.isEmpty else { return [] }

        let spacing = max(0, spacing)
        let sorted = requests.sorted {
            if $0.preferredMidY == $1.preferredMidY {
                return $0.id.uuidString < $1.id.uuidString
            }
            return $0.preferredMidY < $1.preferredMidY
        }
        let requiredHeight = sorted.reduce(0) { $0 + $1.height }
            + spacing * CGFloat(max(0, sorted.count - 1))

        guard requiredHeight <= screenFrame.height else { return nil }

        var frames: [CGRect] = []
        var nextAvailableY = screenFrame.minY

        for request in sorted {
            let highestOrigin = screenFrame.maxY - request.height
            let preferredOrigin = request.preferredMidY - request.height / 2
            let clampedOrigin = min(max(preferredOrigin, screenFrame.minY), highestOrigin)
            let originY = max(clampedOrigin, nextAvailableY)
            frames.append(
                CGRect(
                    x: screenFrame.minX,
                    y: originY,
                    width: screenFrame.width,
                    height: request.height
                )
            )
            nextAvailableY = originY + request.height + spacing
        }

        if let lastFrame = frames.last, lastFrame.maxY > screenFrame.maxY {
            let overflow = lastFrame.maxY - screenFrame.maxY
            frames = frames.map { $0.offsetBy(dx: 0, dy: -overflow) }
        }

        if let firstFrame = frames.first, firstFrame.minY < screenFrame.minY {
            var originY = screenFrame.minY
            frames = sorted.map { request in
                defer { originY += request.height + spacing }
                return CGRect(
                    x: screenFrame.minX,
                    y: originY,
                    width: screenFrame.width,
                    height: request.height
                )
            }
        }

        return zip(sorted, frames).map {
            ShelfDockResolution(id: $0.id, frame: $1)
        }
    }
}
