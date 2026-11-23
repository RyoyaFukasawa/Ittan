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

    @Test("Bookmarks follow files renamed outside Ittan")
    func followsExternalRename() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let original = try fixture.makeFile("Untitled.md")
        let renamed = fixture.root.appendingPathComponent("Meeting Notes.md")

        try fixture.store.save([ShelfItem(url: original)])
        try FileManager.default.moveItem(at: original, to: renamed)

        let item = try #require(fixture.store.load().first)
        #expect(item.path == ShelfItem.normalizedPath(for: renamed))
        #expect(item.displayName == "Meeting Notes.md")
        #expect(item.exists)
    }

    @Test("Managed notes follow an atomic rename that replaces the file identity")
    func followsAtomicManagedRename() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let items = fixture.root.appendingPathComponent("Items", isDirectory: true)
        let directory = items.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let original = directory.appendingPathComponent("Untitled.md")
        try Data().write(to: original)
        let item = ShelfItem(url: original)

        try FileManager.default.removeItem(at: original)
        let renamed = directory.appendingPathComponent("Meeting Notes.md")
        try Data("replacement".utf8).write(to: renamed)

        let refreshed = item.refreshingLocation()
        #expect(refreshed.path == ShelfItem.normalizedPath(for: renamed))
        #expect(refreshed.displayName == "Meeting Notes.md")
        #expect(refreshed.exists)
    }

    @Test("Malformed metadata returns an empty shelf")
    func malformedMetadata() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        try Data("not-json".utf8).write(to: fixture.store.itemsURL)

        #expect(fixture.store.load().isEmpty)
    }

    @Test("Removal history survives a save and load round trip")
    func historyRoundTrip() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let file = try fixture.makeFile("history.txt")
        let item = ShelfItem(url: file, addedAt: Date(timeIntervalSince1970: 1234))

        try fixture.store.saveHistory([item])

        #expect(fixture.store.loadHistory() == [item])
    }

    @Test("A multi-shelf workspace survives a save and load round trip")
    func workspaceRoundTrip() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let leftFile = try fixture.makeFile("left.txt")
        let floatingFile = try fixture.makeFile("floating.txt")
        let removedFile = try fixture.makeFile("removed.txt")
        let savedAt = Date(timeIntervalSince1970: 1_234)
        let leftShelf = ShelfWorkspace.Shelf(
            id: UUID(),
            name: "Left",
            items: [ShelfItem(url: leftFile, addedAt: savedAt)],
            dimensions: .init(width: 378, height: 480),
            placement: .docked(
                screenID: "main",
                edge: .left,
                normalizedMidY: 0.4,
                isCollapsed: true,
                order: 0
            )
        )
        let floatingShelf = ShelfWorkspace.Shelf(
            id: UUID(),
            name: nil,
            items: [ShelfItem(url: floatingFile, addedAt: savedAt)],
            placement: .floating(
                screenID: "main",
                normalizedFrame: CGRect(x: 0.2, y: 0.3, width: 0.25, height: 0.5)
            )
        )
        let workspace = ShelfWorkspace(
            shelves: [leftShelf, floatingShelf],
            history: [ShelfItem(url: removedFile, addedAt: savedAt)],
            activeShelfID: floatingShelf.id
        )

        try fixture.store.saveWorkspace(workspace)

        #expect(
            fixture.store.loadWorkspace(defaultPlacement: leftShelf.placement) == workspace
        )
    }

    @Test("Legacy workspaces without dimensions use the default size")
    func legacyWorkspaceDefaultsDimensions() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let legacyShelf = LegacyShelf(
            id: UUID(),
            name: "Legacy",
            items: [],
            placement: .floating(
                screenID: nil,
                normalizedFrame: CGRect(x: 0.2, y: 0.3, width: 0.25, height: 0.5)
            )
        )
        let legacyWorkspace = LegacyWorkspace(
            version: ShelfWorkspace.currentVersion,
            shelves: [legacyShelf],
            history: [],
            activeShelfID: legacyShelf.id
        )
        try JSONEncoder().encode(legacyWorkspace).write(to: fixture.store.workspaceURL)

        let workspace = fixture.store.loadWorkspace(defaultPlacement: legacyShelf.placement)

        #expect(workspace.shelves.first?.dimensions == .default)
    }

    @Test("Legacy items and history migrate into one workspace shelf")
    func migratesLegacyStorage() throws {
        let fixture = try Fixture()
        defer { fixture.cleanUp() }
        let savedAt = Date(timeIntervalSince1970: 1_234)
        let item = ShelfItem(
            url: try fixture.makeFile("legacy.txt"),
            addedAt: savedAt
        )
        let removedItem = ShelfItem(
            url: try fixture.makeFile("legacy-removed.txt"),
            addedAt: savedAt
        )
        let placement = ShelfPlacement.floating(
            screenID: nil,
            normalizedFrame: CGRect(x: 0.7, y: 0.2, width: 0.2, height: 0.5)
        )
        try fixture.store.save([item])
        try fixture.store.saveHistory([removedItem])

        let workspace = fixture.store.loadWorkspace(defaultPlacement: placement)

        #expect(workspace.shelves.count == 1)
        #expect(workspace.shelves.first?.items == [item])
        #expect(workspace.shelves.first?.placement == placement)
        #expect(workspace.history == [removedItem])
        #expect(workspace.activeShelfID == workspace.shelves.first?.id)
        #expect(FileManager.default.fileExists(atPath: fixture.store.workspaceURL.path))
    }
}

private struct LegacyWorkspace: Encodable {
    let version: Int
    let shelves: [LegacyShelf]
    let history: [ShelfItem]
    let activeShelfID: UUID?
}

private struct LegacyShelf: Encodable {
    let id: UUID
    let name: String?
    let items: [ShelfItem]
    let placement: ShelfPlacement
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
