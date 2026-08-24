enum ToggleShelfItemLock {
    static func apply(id: ShelfItem.ID, to items: inout [ShelfItem]) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return false }
        items[index].isLocked = !items[index].locked
        return true
    }

    static func applyToAll(_ items: inout [ShelfItem]) -> Bool {
        guard !items.isEmpty else { return false }
        let locksItems = items.contains { !$0.locked }
        for index in items.indices {
            items[index].isLocked = locksItems
        }
        return true
    }
}
