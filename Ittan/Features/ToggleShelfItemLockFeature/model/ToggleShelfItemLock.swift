enum ToggleShelfItemLock {
    static func apply(id: ShelfItem.ID, to items: inout [ShelfItem]) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return false }
        items[index].isLocked = !items[index].locked
        return true
    }
}
