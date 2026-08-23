import ComposableArchitecture
import Foundation

struct ShelfStorageClient: Sendable {
    var loadItems: @Sendable () -> [ShelfItem]
    var loadHistory: @Sendable () -> [ShelfItem]
    var saveItems: @Sendable ([ShelfItem]) throws -> Void
    var saveHistory: @Sendable ([ShelfItem]) throws -> Void
    var fileExists: @Sendable (URL) -> Bool
    var createMarkdownNote: @Sendable () throws -> URL
    var rename: @Sendable (URL, String) throws -> URL

    init(store: ShelfStore) {
        loadItems = { store.load() }
        loadHistory = { store.loadHistory() }
        saveItems = { try store.save($0) }
        saveHistory = { try store.saveHistory($0) }
        fileExists = { store.fileManager.fileExists(atPath: $0.path) }
        createMarkdownNote = {
            let directory = store.itemsURL.deletingLastPathComponent()
                .appendingPathComponent("Items", isDirectory: true)
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try store.fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("Untitled.md")
            try Data().write(to: url, options: .atomic)
            return url
        }
        rename = { source, proposedName in
            let name = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !name.contains("/") else { throw RenameError.invalidName }
            let destination = source.deletingLastPathComponent().appendingPathComponent(name)
            guard !store.fileManager.fileExists(atPath: destination.path) else {
                throw RenameError.destinationExists
            }
            try store.fileManager.moveItem(at: source, to: destination)
            return destination
        }
    }

    enum RenameError: Error {
        case invalidName
        case destinationExists
    }
}

extension ShelfStorageClient: DependencyKey {
    static let liveValue = ShelfStorageClient(store: ShelfStore())
    static let testValue = ShelfStorageClient(store: ShelfStore())
}

extension DependencyValues {
    var shelfStorage: ShelfStorageClient {
        get { self[ShelfStorageClient.self] }
        set { self[ShelfStorageClient.self] = newValue }
    }
}
