import Foundation

struct ShelfItem: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    private let storedPath: String
    private let bookmarkData: Data?
    private let volumeIdentifier: UInt64?
    private let fileIdentifier: UInt64?
    let addedAt: Date
    var isLocked: Bool?

    init(id: UUID = UUID(), url: URL, addedAt: Date = Date(), isLocked: Bool? = nil) {
        self.id = id
        let normalizedURL = URL(fileURLWithPath: Self.normalizedPath(for: url))
        self.storedPath = normalizedURL.path
        self.bookmarkData = try? normalizedURL.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        let identity = Self.fileIdentity(at: normalizedURL)
        self.volumeIdentifier = identity?.volume
        self.fileIdentifier = identity?.file
        self.addedAt = addedAt
        self.isLocked = isLocked
    }

    var url: URL {
        let storedURL = URL(fileURLWithPath: storedPath)
        if let bookmarkData {
            var isStale = false
            if let resolved = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withoutUI, .withoutMounting],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ), FileManager.default.fileExists(atPath: resolved.path) {
                return resolved
            }
        }

        if FileManager.default.fileExists(atPath: storedURL.path) {
            return storedURL
        }

        let directory = storedURL.deletingLastPathComponent()
        return resolveUsingFileIdentity(in: directory)
            ?? resolveSingleManagedFile(in: directory)
            ?? storedURL
    }

    var path: String {
        Self.normalizedPath(for: url)
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

    var hasBookmark: Bool {
        bookmarkData != nil && volumeIdentifier != nil && fileIdentifier != nil
    }

    func refreshingLocation() -> Self {
        let resolvedURL = url
        guard Self.normalizedPath(for: resolvedURL) != storedPath,
              FileManager.default.fileExists(atPath: resolvedURL.path) else { return self }
        return Self(id: id, url: resolvedURL, addedAt: addedAt, isLocked: isLocked)
    }

    static func normalizedPath(for url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case path
        case bookmarkData
        case volumeIdentifier
        case fileIdentifier
        case addedAt
        case isLocked
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        storedPath = try container.decode(String.self, forKey: .path)
        bookmarkData = try container.decodeIfPresent(Data.self, forKey: .bookmarkData)
        volumeIdentifier = try container.decodeIfPresent(UInt64.self, forKey: .volumeIdentifier)
        fileIdentifier = try container.decodeIfPresent(UInt64.self, forKey: .fileIdentifier)
        addedAt = try container.decode(Date.self, forKey: .addedAt)
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(path, forKey: .path)
        try container.encodeIfPresent(bookmarkData, forKey: .bookmarkData)
        try container.encodeIfPresent(volumeIdentifier, forKey: .volumeIdentifier)
        try container.encodeIfPresent(fileIdentifier, forKey: .fileIdentifier)
        try container.encode(addedAt, forKey: .addedAt)
        try container.encodeIfPresent(isLocked, forKey: .isLocked)
    }

    private func resolveUsingFileIdentity(in directory: URL) -> URL? {
        guard let volumeIdentifier, let fileIdentifier,
              let candidates = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
              ) else { return nil }

        return candidates.first { candidate in
            guard let identity = Self.fileIdentity(at: candidate) else { return false }
            return identity.volume == volumeIdentifier && identity.file == fileIdentifier
        }
    }

    private func resolveSingleManagedFile(in directory: URL) -> URL? {
        guard directory.deletingLastPathComponent().lastPathComponent == "Items",
              UUID(uuidString: directory.lastPathComponent) != nil,
              let candidates = try? FileManager.default.contentsOfDirectory(
                  at: directory,
                  includingPropertiesForKeys: [.isRegularFileKey],
                  options: [.skipsHiddenFiles]
              ) else { return nil }

        let files = candidates.filter {
            (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        }
        return files.count == 1 ? files[0] : nil
    }

    private static func fileIdentity(at url: URL) -> (volume: UInt64, file: UInt64)? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let volume = attributes[.systemNumber] as? NSNumber,
              let file = attributes[.systemFileNumber] as? NSNumber else { return nil }
        return (volume.uint64Value, file.uint64Value)
    }
}
