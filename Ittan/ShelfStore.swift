import Foundation

struct ShelfStore {
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

    func load() -> [ShelfItem] {
        guard let data = try? Data(contentsOf: itemsURL),
              let decoded = try? JSONDecoder.ittan.decode([ShelfItem].self, from: data) else {
            return []
        }

        return decoded.filter { fileManager.fileExists(atPath: $0.path) }
    }

    func save(_ items: [ShelfItem]) throws {
        let directory = itemsURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder.ittan.encode(items)
        try data.write(to: itemsURL, options: .atomic)
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
