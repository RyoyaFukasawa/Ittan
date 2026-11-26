import ComposableArchitecture
import Foundation
import Testing
@testable import Ittan

@Suite("Shelf workspace feature")
@MainActor
struct ShelfWorkspaceFeatureTests {
    @Test("An empty workspace gains one shelf")
    func ensuresShelf() async throws {
        let fixture = try WorkspaceFeatureFixture()
        defer { fixture.cleanUp() }
        let placement = fixture.defaultPlacement
        let store = fixture.testStore()

        await store.send(.ensureShelf(placement: placement))

        #expect(store.state.shelves.count == 1)
        #expect(store.state.shelves.first?.items.isEmpty == true)
        #expect(store.state.shelves.first?.placement == placement)
        #expect(store.state.activeShelfID == store.state.shelves.first?.id)
    }

    @Test("A workspace that already has one shelf stays unchanged")
    func keepsExistingShelf() async throws {
        let fixture = try WorkspaceFeatureFixture()
        defer { fixture.cleanUp() }
        let shelf = ShelfFeature.State(id: UUID(), placement: fixture.defaultPlacement)
        let store = fixture.testStore(shelves: [shelf], activeShelfID: shelf.id)

        await store.send(.ensureShelf(placement: fixture.defaultPlacement))

        #expect(store.state.shelves.map(\.id) == [shelf.id])
        #expect(store.state.activeShelfID == shelf.id)
    }

    @Test("Extra shelves fold into the active shelf")
    func foldsExtraShelves() async throws {
        let fixture = try WorkspaceFeatureFixture()
        defer { fixture.cleanUp() }
        let keptItem = ShelfItem(url: try fixture.makeFile("kept.txt"))
        let extraItem = ShelfItem(url: try fixture.makeFile("extra.txt"))
        let duplicate = ShelfItem(url: URL(fileURLWithPath: keptItem.path))
        let kept = ShelfFeature.State(
            id: UUID(),
            items: [keptItem],
            placement: fixture.defaultPlacement
        )
        let extra = ShelfFeature.State(
            id: UUID(),
            items: [duplicate, extraItem],
            placement: fixture.defaultPlacement
        )
        let store = fixture.testStore(
            shelves: [extra, kept],
            activeShelfID: kept.id
        )

        await store.send(.ensureShelf(placement: fixture.defaultPlacement))

        #expect(store.state.shelves.map(\.id) == [kept.id])
        #expect(store.state.shelves.first?.items.map(\.path) == [keptItem.path, extraItem.path])
        #expect(store.state.activeShelfID == kept.id)
    }

    @Test("Closing a shelf moves its items into global history")
    func closesShelfIntoHistory() async throws {
        let fixture = try WorkspaceFeatureFixture()
        defer { fixture.cleanUp() }
        let item = ShelfItem(url: try fixture.makeFile("closed.txt"))
        let shelf = ShelfFeature.State(
            id: UUID(),
            items: [item],
            placement: fixture.defaultPlacement
        )
        let store = fixture.testStore(shelves: [shelf], activeShelfID: shelf.id)

        await store.send(.closeShelf(id: shelf.id))

        #expect(store.state.shelves.isEmpty)
        #expect(store.state.history == [item])
        #expect(store.state.activeShelfID == nil)
    }

    @Test("Restoring history with no shelves creates a destination shelf")
    func restoresWithoutExistingShelf() async throws {
        let fixture = try WorkspaceFeatureFixture()
        defer { fixture.cleanUp() }
        let item = ShelfItem(url: try fixture.makeFile("restored.txt"))
        let store = fixture.testStore(history: [item])

        await store.send(.restoreFromHistory(id: item.id, defaultPlacement: fixture.defaultPlacement))

        #expect(store.state.shelves.count == 1)
        #expect(store.state.shelves.first?.items == [item])
        #expect(store.state.history.isEmpty)
        #expect(store.state.activeShelfID == store.state.shelves.first?.id)
    }

    @Test("A completed window move commits its placement")
    func commitsPlacement() async throws {
        let fixture = try WorkspaceFeatureFixture()
        defer { fixture.cleanUp() }
        let shelf = ShelfFeature.State(id: UUID(), placement: fixture.defaultPlacement)
        let placement = ShelfPlacement.docked(
            screenID: "main",
            edge: .right,
            normalizedMidY: 0.7,
            isCollapsed: false,
            order: 1
        )
        let store = fixture.testStore(shelves: [shelf], activeShelfID: shelf.id)

        await store.send(.placementCommitted(id: shelf.id, placement: placement))

        #expect(store.state.shelves[id: shelf.id]?.placement == placement)
    }

    @Test("Appearance keeps the active shelf on the edge of the requested screen")
    func applyAppearance() async {
        let activeID = UUID()
        let otherID = UUID()
        let screen = CGRect(x: 1_440, y: 0, width: 1_920, height: 1_080)
        let otherPlacement = ShelfPlacement.floating(
            screenID: "main",
            normalizedFrame: CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.3)
        )
        let store = TestStore(
            initialState: ShelfWorkspaceFeature.State(shelves: [
                ShelfFeature.State(id: otherID, dimensions: .default, placement: otherPlacement),
                ShelfFeature.State(
                    id: activeID,
                    dimensions: .default,
                    placement: .floating(screenID: "side", normalizedFrame: CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.4))
                ),
            ], activeShelfID: activeID)
        ) {
            ShelfWorkspaceFeature()
        }
        store.dependencies.shelfStorage.saveWorkspace = { _ in }
        let placement = ShelfAppearance.placement(
            edge: .left,
            dimensions: ShelfDimensions.default.displayed(),
            screenID: "external",
            screenFrame: screen,
            normalizedMidY: CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.4).midY
        )

        await store.send(.applyAppearance(
            edge: .left,
            screenID: "external",
            screenFrame: screen
        )) {
            $0.shelves[id: activeID]?.placement = placement
            $0.activeShelfID = activeID
        }
        #expect(store.state.shelves[id: otherID]?.placement == otherPlacement)
        #expect(store.state.shelves[id: otherID]?.dimensions == .default)
    }

    @Test("Clearing recently removed empties the shared history")
    func clearHistory() async {
        let item = ShelfItem(url: URL(fileURLWithPath: "/tmp/ittan-removed.txt"))
        let shelfID = UUID()
        let store = TestStore(
            initialState: ShelfWorkspaceFeature.State(
                shelves: [.init(id: shelfID, history: [item])],
                history: [item],
                activeShelfID: shelfID
            )
        ) {
            ShelfWorkspaceFeature()
        }
        store.dependencies.shelfStorage.saveWorkspace = { _ in }

        await store.send(.clearHistory) {
            $0.history = []
            $0.shelves[id: shelfID]?.history = []
        }
    }

    @Test("Completed resize atomically updates the requested Shelf dimensions and placement")
    func resizeCompleted() async {
        let firstID = UUID()
        let secondID = UUID()
        let store = TestStore(initialState: ShelfWorkspaceFeature.State(shelves: [
            ShelfFeature.State(id: firstID, dimensions: .default),
            ShelfFeature.State(id: secondID, dimensions: .default),
        ])) { ShelfWorkspaceFeature() }
        store.dependencies.shelfStorage.saveWorkspace = { _ in }

        let placement = ShelfPlacement.floating(
            screenID: "main",
            normalizedFrame: CGRect(x: 0.3, y: 0.25, width: 0.25, height: 0.5)
        )
        await store.send(.resizeCompleted(
            id: secondID,
            dimensions: .init(width: 378, height: 480),
            placement: placement
        )) {
            $0.shelves[id: secondID]?.dimensions = .init(width: 378, height: 480)
            $0.shelves[id: secondID]?.placement = placement
            $0.activeShelfID = secondID
        }
    }
}

private struct WorkspaceFeatureFixture {
    let root: URL
    let storage: ShelfStorageClient
    let defaultPlacement = ShelfPlacement.floating(
        screenID: nil,
        normalizedFrame: CGRect(x: 0.7, y: 0.2, width: 0.2, height: 0.5)
    )

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("IttanWorkspaceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        storage = ShelfStorageClient(
            store: ShelfStore(itemsURL: root.appendingPathComponent("items.json"))
        )
    }

    @MainActor
    func testStore(
        shelves: [ShelfFeature.State] = [],
        history: [ShelfItem] = [],
        activeShelfID: UUID? = nil
    ) -> TestStoreOf<ShelfWorkspaceFeature> {
        let store = TestStore(
            initialState: ShelfWorkspaceFeature.State(
                shelves: .init(uniqueElements: shelves),
                history: history,
                activeShelfID: activeShelfID
            )
        ) {
            ShelfWorkspaceFeature()
        } withDependencies: {
            $0.shelfStorage = storage
            $0.uuid = .incrementing
        }
        store.exhaustivity = .off
        return store
    }

    func makeFile(_ name: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try Data().write(to: url)
        return url
    }

    func cleanUp() {
        try? FileManager.default.removeItem(at: root)
    }
}
