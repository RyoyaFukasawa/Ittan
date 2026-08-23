import Foundation

enum CreateShelfNote {
    static func apply(_ url: URL, to items: inout [ShelfItem]) {
        let path = ShelfItem.normalizedPath(for: url)
        items.removeAll { $0.path == path }
        items.insert(ShelfItem(url: url), at: 0)
    }
}
