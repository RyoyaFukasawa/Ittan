import Foundation

enum AddShelfItems {
    @discardableResult
    static func apply(
        _ urls: [URL],
        to items: inout [ShelfItem],
        fileExists: (URL) -> Bool
    ) -> Bool {
        let validURLs = urls.filter { $0.isFileURL && fileExists($0) }
        guard !validURLs.isEmpty else { return false }

        for url in validURLs.reversed() {
            let path = ShelfItem.normalizedPath(for: url)
            items.removeAll { $0.path == path }
            items.insert(ShelfItem(url: url), at: 0)
        }
        return true
    }
}
