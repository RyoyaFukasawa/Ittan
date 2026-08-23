import Foundation

struct ShelfItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let path: String
    let addedAt: Date

    init(id: UUID = UUID(), url: URL, addedAt: Date = Date()) {
        self.id = id
        self.path = Self.normalizedPath(for: url)
        self.addedAt = addedAt
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

    static func normalizedPath(for url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }
}
