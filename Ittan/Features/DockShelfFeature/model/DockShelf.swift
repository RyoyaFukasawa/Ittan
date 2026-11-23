import Foundation

enum DockShelf {
    static func apply(
        id: ShelfFeature.State.ID,
        edge: ShelfEdge,
        preferredMidY: CGFloat,
        screenID: String?,
        screenFrame: CGRect,
        spacing: CGFloat,
        isCollapsed: Bool = false,
        shelves: inout [ShelfFeature.State]
    ) -> Bool {
        guard shelves.contains(where: { $0.id == id }) else { return false }

        let candidates = shelves.filter { shelf in
            if shelf.id == id { return true }
            guard case let .docked(existingScreenID, existingEdge, _, _, _) = shelf.placement else {
                return false
            }
            return existingScreenID == screenID && existingEdge == edge
        }
        let requests = candidates.map { shelf in
            let midpoint: CGFloat
            if shelf.id == id {
                midpoint = preferredMidY
            } else if case let .docked(_, _, normalizedMidY, _, _) = shelf.placement {
                midpoint = screenFrame.minY + normalizedMidY * screenFrame.height
            } else {
                midpoint = preferredMidY
            }
            return ShelfDockRequest(
                id: shelf.id,
                preferredMidY: midpoint,
                height: height(for: shelf)
            )
        }

        guard let resolutions = ShelfPlacementGeometry.resolveDockSlots(
            requests,
            screenFrame: screenFrame,
            spacing: spacing
        ) else { return false }

        for (order, resolution) in resolutions.enumerated() {
            guard let index = shelves.firstIndex(where: { $0.id == resolution.id }) else {
                continue
            }
            let wasCollapsed: Bool
            if resolution.id == id {
                wasCollapsed = isCollapsed
            } else if case let .docked(_, _, _, isCollapsed, _) = shelves[index].placement {
                wasCollapsed = isCollapsed
            } else {
                wasCollapsed = false
            }
            shelves[index].placement = .docked(
                screenID: screenID,
                edge: edge,
                normalizedMidY: (resolution.frame.midY - screenFrame.minY) / screenFrame.height,
                isCollapsed: wasCollapsed,
                order: order
            )
            shelves[index].isPanelCollapsed = wasCollapsed
        }
        return true
    }

    static func height(for shelf: ShelfFeature.State) -> CGFloat {
        if case let .docked(_, _, _, isCollapsed, _) = shelf.placement, isCollapsed {
            return 80
        }
        guard !shelf.items.isEmpty else { return 104 }
        let visibleItems = min(shelf.items.count, 5)
        return CGFloat(visibleItems) * 102 + (shelf.items.count > 5 ? 96 : 72)
    }
}
