import AppKit
import Observation

struct UndoNotice: Identifiable, Equatable {
    let id = UUID()
    let message: String
}

@MainActor
@Observable
final class ShelfController {
    static let shared = ShelfController()

    private(set) var items: [ShelfItem]
    private(set) var history: [ShelfItem]
    private(set) var selectedIDs: Set<ShelfItem.ID> = []
    private(set) var undoNotice: UndoNotice?
    var isDropTargeted = false
    var isPanelCollapsed = false
    @ObservationIgnored var onItemsChanged: (([ShelfItem]) -> Void)?
    @ObservationIgnored var onUndoNoticeChanged: ((UndoNotice?) -> Void)?

    @ObservationIgnored private let store: ShelfStore
    @ObservationIgnored private var selectionAnchor: ShelfItem.ID?
    @ObservationIgnored private var lastRemovedBatch: [ShelfItem] = []
    @ObservationIgnored private var dismissUndoTask: Task<Void, Never>?

    init(store: ShelfStore = ShelfStore()) {
        self.store = store
        self.items = store.load()
        self.history = store.loadHistory()
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
        guard items.first(where: { $0.id == id })?.locked != true else {
            NSSound.beep()
            return
        }
        remove(ids: Set([id]))
    }

    func clear() {
        let removable = items.filter { !$0.locked }
        guard !removable.isEmpty else {
            if !items.isEmpty { NSSound.beep() }
            return
        }
        recordInHistory(removable)
        let removableIDs = Set(removable.map(\.id))
        items.removeAll { removableIDs.contains($0.id) }
        selectedIDs.subtract(removableIDs)
        commit()
    }

    func dragOutSucceeded(ids: [ShelfItem.ID]) {
        let ids = Set(ids)
        let removableIDs = Set(items.filter { ids.contains($0.id) && !$0.locked }.map(\.id))
        guard !removableIDs.isEmpty else { return }
        remove(ids: removableIDs)
    }

    func select(id: ShelfItem.ID, modifiers: NSEvent.ModifierFlags) {
        if modifiers.contains(.shift),
           let anchor = selectionAnchor,
           let anchorIndex = items.firstIndex(where: { $0.id == anchor }),
           let index = items.firstIndex(where: { $0.id == id }) {
            let range = min(anchorIndex, index)...max(anchorIndex, index)
            selectedIDs.formUnion(range.map { items[$0].id })
        } else if modifiers.contains(.command) {
            if selectedIDs.contains(id) { selectedIDs.remove(id) } else { selectedIDs.insert(id) }
            selectionAnchor = id
        } else {
            selectedIDs = [id]
            selectionAnchor = id
        }
    }

    func selectAll() {
        selectedIDs = Set(items.map(\.id))
        selectionAnchor = items.first?.id
    }

    func dragItems(startingWith id: ShelfItem.ID) -> [ShelfItem] {
        if selectedIDs.contains(id) {
            return items.filter { selectedIDs.contains($0.id) && $0.exists }
        }
        selectedIDs = [id]
        selectionAnchor = id
        return items.filter { $0.id == id && $0.exists }
    }

    @discardableResult
    func restoreFromHistory(id: ShelfItem.ID) -> Bool {
        guard let index = history.firstIndex(where: { $0.id == id }) else { return false }
        let item = history[index]
        guard item.exists, !items.contains(where: { $0.path == item.path }) else { return false }
        if lastRemovedBatch.contains(where: { $0.id == id }) {
            dismissUndoTask?.cancel()
            lastRemovedBatch = []
            undoNotice = nil
            onUndoNoticeChanged?(nil)
        }
        history.remove(at: index)
        items.insert(item, at: 0)
        persistHistory()
        commit()
        return true
    }

    func clearHistory() {
        history.removeAll()
        lastRemovedBatch = []
        undoNotice = nil
        onUndoNoticeChanged?(nil)
        dismissUndoTask?.cancel()
        persistHistory()
    }

    @discardableResult
    func createMarkdownNote() -> URL? {
        do {
            let directory = store.itemsURL.deletingLastPathComponent()
                .appendingPathComponent("Items", isDirectory: true)
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("Untitled.md")
            try Data().write(to: url, options: .atomic)
            return add(urls: [url]) == 1 ? url : nil
        } catch {
            NSLog("Ittan: failed to create quick note: \(error.localizedDescription)")
            return nil
        }
    }

    func openMarkdownNote(_ url: URL) {
        let workspace = NSWorkspace.shared
        let editorURL = NoteEditorPreference.applicationURL
        guard FileManager.default.fileExists(atPath: editorURL.path) else {
            NSLog("Ittan: note editor is not available at \(editorURL.path)")
            NSSound.beep()
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        workspace.open([url], withApplicationAt: editorURL, configuration: configuration) { _, error in
            if let error {
                NSLog("Ittan: failed to open quick note: \(error.localizedDescription)")
                NSSound.beep()
            }
        }
    }

    func undoLastRemoval() {
        dismissUndoTask?.cancel()
        let restorable = lastRemovedBatch.filter { item in
            item.exists && !items.contains(where: { $0.path == item.path })
        }
        guard !restorable.isEmpty else {
            undoNotice = nil
            onUndoNoticeChanged?(nil)
            lastRemovedBatch = []
            return
        }
        let restoredIDs = Set(restorable.map(\.id))
        history.removeAll { restoredIDs.contains($0.id) }
        items.insert(contentsOf: restorable, at: 0)
        lastRemovedBatch = []
        undoNotice = nil
        onUndoNoticeChanged?(nil)
        persistHistory()
        commit()
    }

    func toggleLock(id: ShelfItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isLocked = !items[index].locked
        commit()
    }

    @discardableResult
    func rename(id: ShelfItem.ID, to proposedName: String) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == id }), items[index].exists else { return false }
        let oldItem = items[index]
        let name = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !name.contains("/") else { return false }
        let destination = oldItem.url.deletingLastPathComponent().appendingPathComponent(name)
        guard !FileManager.default.fileExists(atPath: destination.path) else { return false }
        do {
            try FileManager.default.moveItem(at: oldItem.url, to: destination)
            items[index] = ShelfItem(
                id: oldItem.id,
                url: destination,
                addedAt: oldItem.addedAt,
                isLocked: oldItem.isLocked
            )
            commit()
            return true
        } catch {
            NSLog("Ittan: failed to rename item: \(error.localizedDescription)")
            return false
        }
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

    private func remove(ids: Set<ShelfItem.ID>) {
        let removed = items.filter { ids.contains($0.id) }
        guard !removed.isEmpty else { return }
        recordInHistory(removed)
        items.removeAll { ids.contains($0.id) }
        selectedIDs.subtract(ids)
        commit()
    }

    private func recordInHistory(_ removed: [ShelfItem]) {
        history.removeAll { old in removed.contains(where: { $0.path == old.path }) }
        history.insert(contentsOf: removed, at: 0)
        if history.count > 50 { history.removeLast(history.count - 50) }
        persistHistory()
        showUndoNotice(for: removed)
    }

    private func persistHistory() {
        do {
            try store.saveHistory(history)
        } catch {
            NSLog("Ittan: failed to persist history: \(error.localizedDescription)")
        }
    }

    private func showUndoNotice(for removed: [ShelfItem]) {
        dismissUndoTask?.cancel()
        lastRemovedBatch = removed
        let message = removed.count == 1
            ? "Removed \(removed[0].displayName)"
            : "Removed \(removed.count) items"
        let notice = UndoNotice(message: message)
        undoNotice = notice
        onUndoNoticeChanged?(notice)
        dismissUndoTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, self?.undoNotice?.id == notice.id else { return }
            self?.undoNotice = nil
            self?.lastRemovedBatch = []
            self?.onUndoNoticeChanged?(nil)
        }
    }
}
