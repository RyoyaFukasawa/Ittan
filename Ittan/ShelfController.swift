import AppKit
import Observation

@MainActor
@Observable
final class ShelfController {
    static let shared = ShelfController()

    private(set) var items: [ShelfItem]
    var isDropTargeted = false
    var isPanelCollapsed = false
    @ObservationIgnored var onItemsChanged: (([ShelfItem]) -> Void)?

    @ObservationIgnored private let store: ShelfStore

    init(store: ShelfStore = ShelfStore()) {
        self.store = store
        self.items = store.load()
    }

    @discardableResult
    func add(urls: [URL]) -> Int {
        let validURLs = urls.filter { url in
            url.isFileURL && FileManager.default.fileExists(atPath: url.path)
        }
        guard !validURLs.isEmpty else { return 0 }

        var added = 0
        for url in validURLs.reversed() {
            let path = ShelfItem.normalizedPath(for: url)
            items.removeAll { $0.path == path }
            items.insert(ShelfItem(url: url), at: 0)
            added += 1
        }
        commit()
        return added
    }

    func remove(id: ShelfItem.ID) {
        let oldCount = items.count
        items.removeAll { $0.id == id }
        guard items.count != oldCount else { return }
        commit()
    }

    func clear() {
        guard !items.isEmpty else { return }
        items.removeAll()
        commit()
    }

    func dragOutSucceeded(id: ShelfItem.ID) {
        remove(id: id)
    }

    func copyToPasteboard(id: ShelfItem.ID) {
        guard let item = items.first(where: { $0.id == id }), item.exists else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([ShelfPasteboardWriter.make(for: item)])
    }

    func open(id: ShelfItem.ID) {
        guard let item = items.first(where: { $0.id == id }), item.exists else { return }
        NSWorkspace.shared.open(item.url)
    }

    func reveal(id: ShelfItem.ID) {
        guard let item = items.first(where: { $0.id == id }), item.exists else { return }
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    private func commit() {
        do {
            try store.save(items)
        } catch {
            NSLog("Ittan: failed to persist shelf: \(error.localizedDescription)")
        }
        onItemsChanged?(items)
    }
}
