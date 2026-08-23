import ComposableArchitecture

@MainActor
enum IttanStore {
    private static let storage = ShelfStorageClient.liveValue

    static let shelf = Store(
        initialState: ShelfFeature.State(
            items: storage.loadItems(),
            history: storage.loadHistory()
        )
    ) {
        ShelfFeature()
    }
}
