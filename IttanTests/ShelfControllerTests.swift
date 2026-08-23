import Foundation
import Testing
@testable import Ittan

@MainActor
@Suite("Shelf controller")
struct ShelfControllerTests {
    @Test("Adding the same normalized path moves it to the front")
    func deduplicatesPaths() throws {
        let fixture = try ControllerFixture()
        defer { fixture.cleanUp() }
        let first = try fixture.makeFile("first.txt")
        let second = try fixture.makeFile("second.txt")
        let controller = ShelfController(store: fixture.store)

        controller.add(urls: [first, second])
        controller.add(urls: [first])

        #expect(controller.items.count == 2)
        #expect(controller.items.first?.path == ShelfItem.normalizedPath(for: first))
    }

    @Test("A successful drag removes only the shelf reference")
    func successfulDragRemovesReference() throws {
        let fixture = try ControllerFixture()
        defer { fixture.cleanUp() }
        let file = try fixture.makeFile("keep-me.txt")
        let controller = ShelfController(store: fixture.store)
        controller.add(urls: [file])
        let id = try #require(controller.items.first?.id)

        controller.dragOutSucceeded(id: id)

        #expect(controller.items.isEmpty)
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test("Nonexistent inputs are ignored")
    func ignoresMissingInput() throws {
        let fixture = try ControllerFixture()
        defer { fixture.cleanUp() }
        let controller = ShelfController(store: fixture.store)

        #expect(controller.add(urls: [fixture.root.appendingPathComponent("missing")]) == 0)
        #expect(controller.items.isEmpty)
    }

    @Test("Locked items remain after a successful drag")
    func lockedItemRemainsAfterDrag() throws {
        let fixture = try ControllerFixture()
        defer { fixture.cleanUp() }
        let file = try fixture.makeFile("locked.txt")
        let controller = ShelfController(store: fixture.store)
        controller.add(urls: [file])
        let id = try #require(controller.items.first?.id)

        controller.toggleLock(id: id)
        controller.dragOutSucceeded(id: id)

        #expect(controller.items.first?.id == id)
        #expect(controller.items.first?.locked == true)
    }

    @Test("Locked items cannot be removed or cleared")
    func lockedItemResistsRemoval() throws {
        let fixture = try ControllerFixture()
        defer { fixture.cleanUp() }
        let lockedFile = try fixture.makeFile("locked.txt")
        let otherFile = try fixture.makeFile("other.txt")
        let controller = ShelfController(store: fixture.store)
        controller.add(urls: [lockedFile, otherFile])
        let lockedID = try #require(
            controller.items.first(where: { $0.displayName == "locked.txt" })?.id
        )
        controller.toggleLock(id: lockedID)

        controller.remove(id: lockedID)
        controller.clear()

        #expect(controller.items.map(\.id) == [lockedID])
        #expect(controller.items.first?.locked == true)
    }

    @Test("Renaming updates both the file and shelf reference")
    func renamesItem() throws {
        let fixture = try ControllerFixture()
        defer { fixture.cleanUp() }
        let file = try fixture.makeFile("before.txt")
        let controller = ShelfController(store: fixture.store)
        controller.add(urls: [file])
        let id = try #require(controller.items.first?.id)

        #expect(controller.rename(id: id, to: "after.txt"))
        #expect(controller.items.first?.displayName == "after.txt")
        #expect(FileManager.default.fileExists(atPath: fixture.root.appendingPathComponent("after.txt").path))
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test("Removed items can be restored from persistent history")
    func restoresRemovedItem() throws {
        let fixture = try ControllerFixture()
        defer { fixture.cleanUp() }
        let file = try fixture.makeFile("restore.txt")
        let controller = ShelfController(store: fixture.store)
        controller.add(urls: [file])
        let id = try #require(controller.items.first?.id)

        controller.remove(id: id)
        #expect(controller.items.isEmpty)
        #expect(controller.history.first?.id == id)

        let reloaded = ShelfController(store: fixture.store)
        reloaded.restoreLastRemoved()
        #expect(reloaded.items.first?.id == id)
        #expect(reloaded.history.isEmpty)
    }

    @Test("Command and shift selection build a multi-item selection")
    func multiSelection() throws {
        let fixture = try ControllerFixture()
        defer { fixture.cleanUp() }
        let urls = try ["one.txt", "two.txt", "three.txt"].map(fixture.makeFile)
        let controller = ShelfController(store: fixture.store)
        controller.add(urls: urls)
        let first = try #require(controller.items.first?.id)
        let last = try #require(controller.items.last?.id)

        controller.select(id: first, modifiers: [])
        controller.select(id: last, modifiers: [.shift])

        #expect(controller.selectedIDs.count == 3)
        #expect(controller.dragItems(startingWith: first).count == 3)
    }

    @Test("Undo restores the most recent removal batch")
    func undoRemovalBatch() throws {
        let fixture = try ControllerFixture()
        defer { fixture.cleanUp() }
        let urls = try ["one.txt", "two.txt", "three.txt"].map(fixture.makeFile)
        let controller = ShelfController(store: fixture.store)
        controller.add(urls: urls)
        let removedIDs = Array(controller.items.prefix(2).map(\.id))

        controller.dragOutSucceeded(ids: removedIDs)
        #expect(controller.items.count == 1)
        #expect(controller.undoNotice != nil)

        controller.undoLastRemoval()
        #expect(controller.items.count == 3)
        #expect(controller.undoNotice == nil)
        #expect(controller.history.isEmpty)
    }

    @Test("Restoring the current removal from history dismisses its undo notice")
    func historyRestoreDismissesUndo() throws {
        let fixture = try ControllerFixture()
        defer { fixture.cleanUp() }
        let file = try fixture.makeFile("restore.txt")
        let controller = ShelfController(store: fixture.store)
        controller.add(urls: [file])
        let id = try #require(controller.items.first?.id)
        controller.remove(id: id)
        #expect(controller.undoNotice != nil)

        #expect(controller.restoreFromHistory(id: id))

        #expect(controller.undoNotice == nil)
        #expect(controller.items.first?.id == id)
    }
}

private struct ControllerFixture {
    let root: URL
    let store: ShelfStore

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("IttanControllerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        store = ShelfStore(itemsURL: root.appendingPathComponent("items.json"))
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
