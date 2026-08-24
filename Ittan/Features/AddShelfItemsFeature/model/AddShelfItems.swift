import Foundation

enum AddShelfItems {
    @discardableResult
    static func apply(
        _ urls: [URL],
        to items: inout [ShelfItem],
        at insertionIndex: Int = 0,
        fileExists: (URL) -> Bool
    ) -> Bool {
        let validURLs = urls.filter { $0.isFileURL && fileExists($0) }
        guard !validURLs.isEmpty else { return false }

        var seenPaths: Set<String> = []
        let uniqueURLs = validURLs.filter { url in
            seenPaths.insert(ShelfItem.normalizedPath(for: url)).inserted
        }
        let paths = Set(uniqueURLs.map { ShelfItem.normalizedPath(for: $0) })
        let clampedInsertionIndex = min(max(0, insertionIndex), items.endIndex)
        let removedBeforeInsertion = items[..<clampedInsertionIndex]
            .count { paths.contains($0.path) }
        let adjustedInsertionIndex = clampedInsertionIndex - removedBeforeInsertion
        items.removeAll { paths.contains($0.path) }
        let newItems = uniqueURLs.map { ShelfItem(url: $0) }
        items.insert(
            contentsOf: newItems,
            at: min(adjustedInsertionIndex, items.endIndex)
        )
        return true
    }
}
