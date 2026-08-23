import Foundation

struct ShelfItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let path: String
    let addedAt: Date
    var isLocked: Bool?

    init(id: UUID = UUID(), url: URL, addedAt: Date = Date(), isLocked: Bool? = nil) {
        self.id = id
        self.path = Self.normalizedPath(for: url)
        self.addedAt = addedAt
        self.isLocked = isLocked
    }

    var url: URL {
        URL(fileURLWithPath: path)
    }

    var displayName: String {
        url.lastPathComponent
    }

    var parentName: String {
        url.deletingLastPathComponent().lastPathComponent
    }

    var exists: Bool {
        FileManager.default.fileExists(atPath: path)
    }

    var locked: Bool { isLocked == true }

    static func normalizedPath(for url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }
}
