import ComposableArchitecture
import Foundation
import Testing
@testable import Ittan

@MainActor
@Suite("Shelf feature")
struct ShelfFeatureTests {
    @Test("Adding the same normalized path moves it to the front")
    func deduplicatesPaths() async throws {
        let fixture = try FeatureFixture()
        defer { fixture.cleanUp() }
        let first = try fixture.makeFile("first.txt")
        let second = try fixture.makeFile("second.txt")
        let store = fixture.testStore()
        store.exhaustivity = .off

        await store.send(.addURLs([first, second]))
        await store.send(.addURLs([first]))

        #expect(store.state.items.count == 2)
        #expect(store.state.items.first?.path == ShelfItem.normalizedPath(for: first))
    }

    @Test("A successful drag removes only the shelf reference and Undo restores it")
    func dragAndUndo() async throws {
        let fixture = try FeatureFixture()
        defer { fixture.cleanUp() }
        let file = try fixture.makeFile("keep-me.txt")
        let item = ShelfItem(url: file)
        let store = fixture.testStore(items: [item])
        store.exhaustivity = .off

        await store.send(.dragOutSucceeded([item.id]))
        #expect(store.state.items.isEmpty)
        #expect(store.state.history == [item])
        #expect(FileManager.default.fileExists(atPath: file.path))

        await store.send(.undoButtonTapped)
        #expect(store.state.items == [item])
        #expect(store.state.history.isEmpty)
        #expect(store.state.undoNotice == nil)
    }

    @Test("Locked items cannot be removed or cleared")
    func lockedItemResistsRemoval() async throws {
        let fixture = try FeatureFixture()
        defer { fixture.cleanUp() }
        let lockedURL = try fixture.makeFile("locked.txt")
        let otherURL = try fixture.makeFile("other.txt")
        var locked = ShelfItem(url: lockedURL)
        locked.isLocked = true
        let other = ShelfItem(url: otherURL)
        let store = fixture.testStore(items: [locked, other])
        store.exhaustivity = .off

        await store.send(.removeButtonTapped(locked.id))
        await store.send(.clearButtonTapped)

        #expect(store.state.items == [locked])
    }

    @Test("Toggle all locks locks mixed items and then unlocks them")
    func togglesAllLocks() async throws {
        let fixture = try FeatureFixture()
        defer { fixture.cleanUp() }
        var locked = ShelfItem(url: try fixture.makeFile("already-locked.txt"))
        locked.isLocked = true
        let unlocked = ShelfItem(url: try fixture.makeFile("unlocked.txt"))
        let store = fixture.testStore(items: [locked, unlocked])
        store.exhaustivity = .off

        await store.send(.toggleAllLocks)
        #expect(!store.state.items.contains { !$0.locked })

        await store.send(.toggleAllLocks)
        #expect(store.state.items.allSatisfy { !$0.locked })
    }

    @Test("Renaming updates both the file and shelf reference")
    func renamesItem() async throws {
        let fixture = try FeatureFixture()
        defer { fixture.cleanUp() }
        let file = try fixture.makeFile("before.txt")
        let item = ShelfItem(url: file)
        let store = fixture.testStore(items: [item])
        store.exhaustivity = .off

        await store.send(.renameRequested(item.id, "after.txt"))

        #expect(store.state.items.first?.displayName == "after.txt")
        #expect(FileManager.default.fileExists(atPath: fixture.root.appendingPathComponent("after.txt").path))
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test("Refreshing file locations updates externally renamed items")
    func refreshesExternallyRenamedItem() async throws {
        let fixture = try FeatureFixture()
        defer { fixture.cleanUp() }
        let file = try fixture.makeFile("before.txt")
        let item = ShelfItem(url: file)
        let renamed = fixture.root.appendingPathComponent("after.txt")
        let store = fixture.testStore(items: [item])
        store.exhaustivity = .off
        try FileManager.default.moveItem(at: file, to: renamed)

        await store.send(.refreshFileLocations)

        #expect(store.state.items.first?.displayName == "after.txt")
        #expect(store.state.items.first?.exists == true)
    }

    @Test("Command and shift selection build a multi-item selection")
    func multiSelection() async throws {
        let fixture = try FeatureFixture()
        defer { fixture.cleanUp() }
        let items = try ["one.txt", "two.txt", "three.txt"].map {
            ShelfItem(url: try fixture.makeFile($0))
        }
        let store = fixture.testStore(items: items)
        store.exhaustivity = .off

        await store.send(.select(items[0].id, []))
        await store.send(.select(items[2].id, [.shift]))

        #expect(store.state.selectedIDs.count == 3)
        #expect(store.state.dragItems(startingWith: items[0].id).count == 3)
    }

    @Test("Restoring from history dismisses the current Undo notice")
    func restoreFromHistory() async throws {
        let fixture = try FeatureFixture()
        defer { fixture.cleanUp() }
        let item = ShelfItem(url: try fixture.makeFile("restore.txt"))
        let store = fixture.testStore(items: [item])
        store.exhaustivity = .off

        await store.send(.removeButtonTapped(item.id))
        await store.send(.restoreFromHistory(item.id))

        #expect(store.state.items == [item])
        #expect(store.state.history.isEmpty)
        #expect(store.state.undoNotice == nil)
    }

    @Test("Undo remains available after its toast expires and supports redo")
    func undoAfterToastAndRedo() async throws {
        let fixture = try FeatureFixture()
        defer { fixture.cleanUp() }
        let item = ShelfItem(url: try fixture.makeFile("undo-redo.txt"))
        let store = fixture.testStore(items: [item])
        store.exhaustivity = .off

        await store.send(.removeButtonTapped(item.id))
        let noticeID = try #require(store.state.undoNotice?.id)
        await store.send(.undoExpired(noticeID))
        #expect(store.state.undoNotice == nil)

        await store.send(.undoButtonTapped)
        #expect(store.state.items == [item])

        await store.send(.redoButtonTapped)
        #expect(store.state.items.isEmpty)
        #expect(store.state.history == [item])
    }

    @Test("Removing a selection keeps locked items on the shelf")
    func removesUnlockedSelection() async throws {
        let fixture = try FeatureFixture()
        defer { fixture.cleanUp() }
        var locked = ShelfItem(url: try fixture.makeFile("locked-selection.txt"))
        locked.isLocked = true
        let removable = ShelfItem(url: try fixture.makeFile("removable-selection.txt"))
        var state = ShelfFeature.State(items: [locked, removable])
        state.selectedIDs = [locked.id, removable.id]
        let store = TestStore(initialState: state) {
            ShelfFeature()
        } withDependencies: {
            $0.shelfStorage = fixture.storage
            $0.continuousClock = TestClock()
            $0.uuid = .incrementing
        }
        store.exhaustivity = .off

        await store.send(.removeSelected)

        #expect(store.state.items == [locked])
    }
}

private struct FeatureFixture {
    let root: URL
    let storage: ShelfStorageClient

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("IttanFeatureTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        storage = ShelfStorageClient(
            store: ShelfStore(itemsURL: root.appendingPathComponent("items.json"))
        )
    }

    @MainActor
    func testStore(items: [ShelfItem] = []) -> TestStoreOf<ShelfFeature> {
        TestStore(initialState: ShelfFeature.State(items: items)) {
            ShelfFeature()
        } withDependencies: {
            $0.shelfStorage = storage
            $0.continuousClock = TestClock()
            $0.uuid = .incrementing
        }
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
