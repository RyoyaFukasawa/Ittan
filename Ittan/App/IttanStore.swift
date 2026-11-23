import AppKit
import ComposableArchitecture
import Foundation

@MainActor
enum IttanStore {
    private static let storage = ShelfStorageClient.liveValue
    static var defaultPlacement: ShelfPlacement {
        let screen = ScreenResolver.screenUnderPointer() ?? NSScreen.main
        let screenFrame = screen?.frame ?? CGRect(x: 0, y: 0, width: 1_440, height: 900)
        return ShelfAppearance.placement(
            edge: IttanPreferences.shelfEdge,
            dimensions: ShelfDimensions.default.displayed(),
            screenID: screen.flatMap { ScreenResolver.identifier(for: $0) },
            screenFrame: screenFrame
        )
    }
    private static let initialWorkspace = storage.loadWorkspace(defaultPlacement)

    static let workspace = Store(
        initialState: ShelfWorkspaceFeature.State(workspace: initialWorkspace)
    ) {
        ShelfWorkspaceFeature()
    }
}
