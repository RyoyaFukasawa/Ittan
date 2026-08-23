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
