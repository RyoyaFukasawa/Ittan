import CoreGraphics

enum ShelfDockingAvailability {
    // Temporarily disabled while floating shelf interactions are refined.
    // Set this back to true when docking, edge tabs, and collapse gestures
    // are ready to be adjusted together.
    static let isEnabled = false

    static func activePlacement(_ placement: ShelfPlacement) -> ShelfPlacement {
        guard !isEnabled,
              case let .docked(screenID, edge, normalizedMidY, _, _) = placement else {
            return placement
        }
        return .floating(
            screenID: screenID,
            normalizedFrame: CGRect(
                x: edge == .left ? 0.03 : 0.77,
                y: min(max(normalizedMidY - 0.25, 0), 0.5),
                width: 0.2,
                height: 0.5
            )
        )
    }
}
