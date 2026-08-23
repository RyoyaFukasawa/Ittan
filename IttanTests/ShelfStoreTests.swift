import Foundation
import Testing
@testable import Ittan

@Suite("Shelf storage")
struct ShelfStoreTests {
    @Test("Items survive a save and load round trip")
    func roundTrip() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let file = try fixture.makeFile("example.txt")
        let item = ShelfItem(url: file, addedAt: Date(timeIntervalSince1970: 1234))

        try fixture.store.save([item])

        #expect(fixture.store.load() == [item])
    }

    @Test("Missing paths are discarded while loading")
    func missingPathsAreDiscarded() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let missing = fixture.root.appendingPathComponent("missing.txt")

        try fixture.store.save([ShelfItem(url: missing)])

        #expect(fixture.store.load().isEmpty)
    }

    @Test("Malformed metadata returns an empty shelf")
    func malformedMetadata() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        try Data("not-json".utf8).write(to: fixture.store.itemsURL)

        #expect(fixture.store.load().isEmpty)
    }
}

private struct Fixture {
    let root: URL
    let store: ShelfStore

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("IttanTests-\(UUID().uuidString)", isDirectory: true)
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
