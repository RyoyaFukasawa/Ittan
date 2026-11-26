import AppKit
import ComposableArchitecture
import Foundation

@MainActor
final class ShelfWindowCoordinator {
    static let shared = ShelfWindowCoordinator(store: IttanStore.workspace)

    private let store: StoreOf<ShelfWorkspaceFeature>
    private var controllers: [ShelfFeature.State.ID: ShelfPanelController] = [:]
    private var activeShelfID: ShelfFeature.State.ID?

    init(store: StoreOf<ShelfWorkspaceFeature>) {
        self.store = store
    }

    func synchronize() {
        activeShelfID = store.activeShelfID
        let shelves = Array(store.shelves)
        let currentIDs = Set(shelves.map(\.id))

        for shelf in shelves {
            let activePlacement = ShelfDockingAvailability.activePlacement(shelf.placement)
            if activePlacement != shelf.placement {
                store.send(.placementCommitted(id: shelf.id, placement: activePlacement))
            }
            let controller = controllers[shelf.id] ?? makeController(for: shelf)
            controllers[shelf.id] = controller
            controller.synchronize(
                placement: activePlacement,
                dimensions: shelf.dimensions
            )
            controller.layoutDidChange(shelf.items)
            if !shelf.items.isEmpty {
                controller.show()
            }
        }

        for id in Set(controllers.keys).subtracting(currentIDs) {
            controllers.removeValue(forKey: id)?.close()
        }
    }

    func showActive() {
        activeController?.holdVisibleWhileEmpty()
        relocateActiveShelfToPointer()
        activeController?.show()
    }

    func clearActive() {
        guard let activeShelfID else { return }
        store.send(.shelves(.element(id: activeShelfID, action: .clearButtonTapped)))
    }

    func preferencesDidChange() {
        controllers.values.forEach { $0.preferencesDidChange() }
    }

    func applyAppearancePreferences() {
        guard let screen = screenForActiveShelf() else { return }
        moveActiveShelf(to: screen)
    }

    func relocateActiveShelfToPointer() {
        guard let screen = ScreenResolver.screenUnderPointer() else { return }
        let screenID = ScreenResolver.identifier(for: screen)
        guard activeShelfScreenID != screenID else { return }
        let shouldShow = activeController?.isVisible == true
        moveActiveShelf(to: screen)
        if shouldShow {
            activeController?.show(on: screen)
        }
    }

    func externalDragStarted(on screen: NSScreen?) {
        activeController?.externalDragStarted(on: screen)
    }

    func externalDragEnded() {
        controllers.values.forEach { $0.externalDragEnded() }
    }

    private var activeShelfScreenID: String? {
        guard let activeShelfID else { return nil }
        return store.shelves[id: activeShelfID]?.placement.screenID
    }

    private func screenForActiveShelf() -> NSScreen? {
        if let screen = ScreenResolver.screen(withIdentifier: activeShelfScreenID) {
            return screen
        }
        return activeController?.hostingScreen
            ?? ScreenResolver.screenUnderPointer()
            ?? NSScreen.main
    }

    private func moveActiveShelf(to screen: NSScreen) {
        store.send(.applyAppearance(
            edge: IttanPreferences.shelfEdge,
            screenID: ScreenResolver.identifier(for: screen),
            screenFrame: screen.frame
        ))
    }

    private var activeController: ShelfPanelController? {
        if let activeShelfID, let controller = controllers[activeShelfID] {
            return controller
        }
        return controllers.values.first
    }

    private func makeController(for shelf: ShelfFeature.State) -> ShelfPanelController {
        let id = shelf.id
        guard let shelfStore = store.scope(
            state: \.shelves[id: id],
            action: \.shelves[id: id]
        ) else {
            preconditionFailure("Shelf must exist while creating its window")
        }
        return ShelfPanelController(
            store: shelfStore,
            placement: ShelfDockingAvailability.activePlacement(shelf.placement),
            onPlacementCommitted: { [weak self] placement in
                guard let self else { return }
                if case let .docked(screenID, edge, normalizedMidY, isCollapsed, _) = placement,
                   let screen = ScreenResolver.screen(withIdentifier: screenID)
                        ?? NSScreen.main {
                    self.store.send(
                        .dockShelf(
                            id: id,
                            edge: edge,
                            preferredMidY: screen.frame.minY
                                + normalizedMidY * screen.frame.height,
                            screenID: screenID,
                            screenFrame: screen.frame,
                            isCollapsed: isCollapsed
                        )
                    )
                } else {
                    self.store.send(.placementCommitted(id: id, placement: placement))
                }
            },
            onResizeCommitted: { [weak self] dimensions, placement in
                self?.store.send(.resizeCompleted(
                    id: id,
                    dimensions: dimensions,
                    placement: placement
                ))
            }
        )
    }
}
