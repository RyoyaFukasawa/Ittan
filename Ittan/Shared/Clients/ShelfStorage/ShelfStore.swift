import Foundation

struct ShelfStore: @unchecked Sendable {
    let itemsURL: URL
    let fileManager: FileManager

    init(
        itemsURL: URL = ShelfStore.defaultItemsURL,
        fileManager: FileManager = .default
    ) {
        self.itemsURL = itemsURL
        self.fileManager = fileManager
    }

    static var defaultItemsURL: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)

        return base
            .appendingPathComponent("Ittan", isDirectory: true)
            .appendingPathComponent("items.json", isDirectory: false)
    }

    var historyURL: URL {
        itemsURL.deletingLastPathComponent().appendingPathComponent("history.json")
    }

    var workspaceURL: URL {
        itemsURL.deletingLastPathComponent().appendingPathComponent("workspace.json")
    }

    func loadWorkspace(defaultPlacement: ShelfPlacement) -> ShelfWorkspace {
        if fileManager.fileExists(atPath: workspaceURL.path) {
            guard let data = try? Data(contentsOf: workspaceURL),
                  let workspace = try? JSONDecoder.ittan.decode(ShelfWorkspace.self, from: data),
                  workspace.version == ShelfWorkspace.currentVersion else {
                return ShelfWorkspace(shelves: [], history: [], activeShelfID: nil)
            }
            return workspace
        }

        // Legacy migration contract: keep these readers until every supported
        // release has written workspace.json at least once.
        let legacyItems = load()
        let legacyHistory = loadHistory()
        let shelf = legacyItems.isEmpty
            ? nil
            : ShelfWorkspace.Shelf(
                id: UUID(),
                name: nil,
                items: legacyItems,
                placement: defaultPlacement
            )
        let workspace = ShelfWorkspace(
            shelves: shelf.map { [$0] } ?? [],
            history: legacyHistory,
            activeShelfID: shelf?.id
        )
        try? saveWorkspace(workspace)
        return workspace
    }

    func saveWorkspace(_ workspace: ShelfWorkspace) throws {
        let directory = workspaceURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder.ittan.encode(workspace)
        try data.write(to: workspaceURL, options: .atomic)
    }

    func load() -> [ShelfItem] {
        guard let data = try? Data(contentsOf: itemsURL),
              let decoded = try? JSONDecoder.ittan.decode([ShelfItem].self, from: data) else {
            return []
        }

        let upgraded = decoded.map { item in
            item.hasBookmark
                ? item.refreshingLocation()
                : ShelfItem(
                    id: item.id,
                    url: item.url,
                    addedAt: item.addedAt,
                    isLocked: item.isLocked
                )
        }
        let available = upgraded.filter { fileManager.fileExists(atPath: $0.path) }
        if upgraded != decoded || available.count != upgraded.count {
            try? save(available)
        }
        return available
    }

    func save(_ items: [ShelfItem]) throws {
        let directory = itemsURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder.ittan.encode(items)
        try data.write(to: itemsURL, options: .atomic)
    }

    func loadHistory() -> [ShelfItem] {
        guard let data = try? Data(contentsOf: historyURL),
              let decoded = try? JSONDecoder.ittan.decode([ShelfItem].self, from: data) else {
            return []
        }
        let upgraded = decoded.map { item in
            item.hasBookmark
                ? item.refreshingLocation()
                : ShelfItem(
                    id: item.id,
                    url: item.url,
                    addedAt: item.addedAt,
                    isLocked: item.isLocked
                )
        }
        let existing = upgraded.filter { fileManager.fileExists(atPath: $0.path) }
        let available = Array(existing.prefix(IttanPreferences.historyLimit))
        if upgraded != decoded || available.count != upgraded.count {
            try? saveHistory(available)
        }
        return available
    }

    func saveHistory(_ items: [ShelfItem]) throws {
        let directory = historyURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder.ittan.encode(items)
        try data.write(to: historyURL, options: .atomic)
    }
}

private extension JSONEncoder {
    static var ittan: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var ittan: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
