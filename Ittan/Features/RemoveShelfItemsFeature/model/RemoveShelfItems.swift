import Foundation

struct UndoNotice: Identifiable, Equatable, Sendable {
    let id: UUID
    let message: String

    init(id: UUID = UUID(), message: String) {
        self.id = id
        self.message = message
    }
}

enum RemoveShelfItems {
    static func apply(
        ids: Set<ShelfItem.ID>,
        items: inout [ShelfItem],
        selectedIDs: inout Set<ShelfItem.ID>
    ) -> [ShelfItem] {
        let removed = items.filter { ids.contains($0.id) }
        items.removeAll { ids.contains($0.id) }
        selectedIDs.subtract(ids)
        return removed
    }

    static func record(
        _ removed: [ShelfItem],
        history: inout [ShelfItem],
        lastRemovedBatch: inout [ShelfItem],
        undoNotice: inout UndoNotice?,
        noticeID: UUID,
        historyLimit: Int
    ) {
        history.removeAll { old in removed.contains(where: { $0.path == old.path }) }
        history.insert(contentsOf: removed, at: 0)
        if history.count > historyLimit {
            history.removeLast(history.count - historyLimit)
        }
        lastRemovedBatch = removed
        undoNotice = UndoNotice(
            id: noticeID,
            message: removed.count == 1
                ? "Removed \(removed[0].displayName)"
                : "Removed \(removed.count) items"
        )
    }
}
