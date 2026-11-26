import ComposableArchitecture
import Foundation

@Reducer
struct ShelfWorkspaceFeature {
    @ObservableState
    struct State: Equatable {
        var shelves: IdentifiedArrayOf<ShelfFeature.State>
        var history: [ShelfItem]
        var activeShelfID: ShelfFeature.State.ID?

        init(
            shelves: IdentifiedArrayOf<ShelfFeature.State> = [],
            history: [ShelfItem] = [],
            activeShelfID: ShelfFeature.State.ID? = nil
        ) {
            self.shelves = shelves
            self.history = history
            self.activeShelfID = activeShelfID
        }

        init(workspace: ShelfWorkspace) {
            shelves = .init(
                uniqueElements: workspace.shelves.map {
                    ShelfFeature.State(
                        id: $0.id,
                        name: $0.name,
                        items: $0.items,
                        history: workspace.history,
                        dimensions: $0.dimensions,
                        placement: $0.placement
                    )
                }
            )
            history = workspace.history
            activeShelfID = workspace.activeShelfID
        }

        var workspace: ShelfWorkspace {
            ShelfWorkspace(
                shelves: shelves.map {
                    ShelfWorkspace.Shelf(
                        id: $0.id,
                        name: $0.name,
                        items: $0.items,
                        dimensions: $0.dimensions,
                        placement: $0.placement
                    )
                },
                history: history,
                activeShelfID: activeShelfID
            )
        }
    }

    enum Action: Equatable {
        case activateShelf(id: ShelfFeature.State.ID)
        case addURLs([URL], to: ShelfFeature.State.ID)
        case closeShelf(id: ShelfFeature.State.ID)
        case ensureShelf(placement: ShelfPlacement)
        case dockShelf(
            id: ShelfFeature.State.ID,
            edge: ShelfEdge,
            preferredMidY: CGFloat,
            screenID: String?,
            screenFrame: CGRect,
            isCollapsed: Bool
        )
        case applyAppearance(
            edge: ShelfEdge,
            screenID: String?,
            screenFrame: CGRect
        )
        case clearHistory
        case historyLimitChanged(Int)
        case placementCommitted(id: ShelfFeature.State.ID, placement: ShelfPlacement)
        case resizeCompleted(
            id: ShelfFeature.State.ID,
            dimensions: ShelfDimensions,
            placement: ShelfPlacement
        )
        case restoreFromHistory(id: ShelfItem.ID, defaultPlacement: ShelfPlacement)
        case shelves(IdentifiedActionOf<ShelfFeature>)
    }

    @Dependency(\.shelfStorage) var storage
    @Dependency(\.uuid) var uuid

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .activateShelf(id):
                guard state.shelves[id: id] != nil else { return .none }
                state.activeShelfID = id

            case let .addURLs(urls, id):
                guard var shelf = state.shelves[id: id] else { return .none }
                guard AddShelfItems.apply(
                    urls,
                    to: &shelf.items,
                    fileExists: storage.fileExists
                ) else { return .none }
                state.shelves[id: id] = shelf
                state.activeShelfID = id

            case let .closeShelf(id):
                guard let shelf = state.shelves.remove(id: id) else { return .none }
                let existingIDs = Set(state.history.map(\.id))
                let closedItems = shelf.items.filter { !existingIDs.contains($0.id) }
                state.history.insert(contentsOf: closedItems, at: 0)
                state.history = Array(state.history.prefix(IttanPreferences.historyLimit))
                if state.activeShelfID == id {
                    state.activeShelfID = state.shelves.first?.id
                }

            case let .ensureShelf(placement):
                if state.shelves.isEmpty {
                    let shelf = ShelfFeature.State(
                        id: uuid(),
                        items: [],
                        history: state.history,
                        dimensions: .default,
                        placement: placement
                    )
                    state.shelves.append(shelf)
                    state.activeShelfID = shelf.id
                } else if !keepSingleShelf(&state) {
                    return .none
                }

            case let .dockShelf(id, edge, preferredMidY, screenID, screenFrame, isCollapsed):
                var shelves = Array(state.shelves)
                guard DockShelf.apply(
                    id: id,
                    edge: edge,
                    preferredMidY: preferredMidY,
                    screenID: screenID,
                    screenFrame: screenFrame,
                    spacing: 12,
                    isCollapsed: isCollapsed,
                    shelves: &shelves
                ) else { return .none }
                state.shelves = .init(uniqueElements: shelves)
                state.activeShelfID = id

            case let .applyAppearance(edge, screenID, screenFrame):
                let targetID = state.activeShelfID ?? state.shelves.first?.id
                if let targetID, var shelf = state.shelves[id: targetID] {
                    shelf.placement = ShelfAppearance.placement(
                        edge: edge,
                        dimensions: shelf.dimensions.displayed(),
                        screenID: screenID,
                        screenFrame: screenFrame,
                        normalizedMidY: shelf.placement.verticalAnchor
                    )
                    state.shelves[id: targetID] = shelf
                    state.activeShelfID = targetID
                }

            case .clearHistory:
                state.history = []
                for id in state.shelves.ids {
                    state.shelves[id: id]?.history = []
                    state.shelves[id: id]?.lastRemovedBatch = []
                    state.shelves[id: id]?.redoBatch = []
                }

            case let .historyLimitChanged(limit):
                guard limit > 0, state.history.count > limit else { return .none }
                state.history.removeLast(state.history.count - limit)

            case let .placementCommitted(id, placement):
                guard var shelf = state.shelves[id: id] else { return .none }
                shelf.placement = placement
                if case let .docked(_, _, _, isCollapsed, _) = placement {
                    shelf.isPanelCollapsed = isCollapsed
                } else {
                    shelf.isPanelCollapsed = false
                }
                state.shelves[id: id] = shelf

            case let .resizeCompleted(id, dimensions, placement):
                guard var shelf = state.shelves[id: id] else { return .none }
                shelf.dimensions = dimensions
                shelf.placement = placement
                shelf.isPanelCollapsed = false
                state.shelves[id: id] = shelf
                state.activeShelfID = id

            case let .restoreFromHistory(id, defaultPlacement):
                guard let historyIndex = state.history.firstIndex(where: { $0.id == id }) else {
                    return .none
                }
                let item = state.history[historyIndex]
                guard storage.fileExists(item.url) else { return .none }

                let destinationID = state.activeShelfID.flatMap {
                    state.shelves[id: $0] == nil ? nil : $0
                } ?? state.shelves.first?.id

                if let destinationID, var shelf = state.shelves[id: destinationID] {
                    guard !shelf.items.contains(where: { $0.path == item.path }) else { return .none }
                    shelf.items.insert(item, at: 0)
                    state.shelves[id: destinationID] = shelf
                    state.activeShelfID = destinationID
                } else {
                    let shelf = ShelfFeature.State(
                        id: uuid(),
                        items: [item],
                        history: [],
                        placement: defaultPlacement
                    )
                    state.shelves.append(shelf)
                    state.activeShelfID = shelf.id
                }
                state.history.remove(at: historyIndex)

            case let .shelves(.element(id, _)):
                state.activeShelfID = id
                return .none
            }

            persist(state.workspace)
            return .none
        }
        .forEach(\.shelves, action: \.shelves) {
            ShelfFeature()
        }
        Reduce { state, action in
            guard case let .shelves(.element(id, _)) = action,
                  let shelf = state.shelves[id: id] else { return .none }

            state.history = shelf.history
            let sharedHistory = state.history
            for shelfID in state.shelves.ids {
                state.shelves[id: shelfID]?.history = sharedHistory
            }
            persist(state.workspace)
            return .none
        }
    }

    /// Folds every extra shelf into the active one. Returns false when the
    /// workspace already has exactly one active shelf.
    private func keepSingleShelf(_ state: inout State) -> Bool {
        let keptID = state.activeShelfID.flatMap { id in
            state.shelves[id: id] == nil ? nil : id
        } ?? state.shelves.ids.first
        guard let keptID, var kept = state.shelves[id: keptID] else { return false }

        let extras = state.shelves.filter { $0.id != keptID }
        guard !extras.isEmpty || state.activeShelfID != keptID else { return false }

        if !extras.isEmpty {
            var seen = Set(kept.items.map(\.path))
            for extra in extras {
                for item in extra.items where seen.insert(item.path).inserted {
                    kept.items.append(item)
                }
            }
            state.shelves = .init(uniqueElements: [kept])
        }
        state.activeShelfID = keptID
        return true
    }

    private func persist(_ workspace: ShelfWorkspace) {
        do {
            try storage.saveWorkspace(workspace)
        } catch {
            NSLog("Ittan: failed to persist workspace: \(error.localizedDescription)")
        }
    }
}
