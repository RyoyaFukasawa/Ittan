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
        let available = upgraded.filter { fileManager.fileExists(atPath: $0.path) }
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
