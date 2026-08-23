import Foundation

struct SelectionModifiers: OptionSet, Equatable, Sendable {
    let rawValue: Int

    static let command = Self(rawValue: 1 << 0)
    static let shift = Self(rawValue: 1 << 1)

    init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

enum SelectShelfItems {
    static func apply(
        id: ShelfItem.ID,
        modifiers: SelectionModifiers,
        items: [ShelfItem],
        selectedIDs: inout Set<ShelfItem.ID>,
        selectionAnchor: inout ShelfItem.ID?
    ) {
        if modifiers.contains(.shift),
           let anchor = selectionAnchor,
           let anchorIndex = items.firstIndex(where: { $0.id == anchor }),
           let index = items.firstIndex(where: { $0.id == id }) {
            let range = min(anchorIndex, index)...max(anchorIndex, index)
            selectedIDs.formUnion(range.map { items[$0].id })
        } else if modifiers.contains(.command) {
            if selectedIDs.contains(id) {
                selectedIDs.remove(id)
            } else {
                selectedIDs.insert(id)
            }
            selectionAnchor = id
        } else {
            selectedIDs = [id]
            selectionAnchor = id
        }
    }

    static func selectAll(
        items: [ShelfItem],
        selectedIDs: inout Set<ShelfItem.ID>,
        selectionAnchor: inout ShelfItem.ID?
    ) {
        selectedIDs = Set(items.map(\.id))
        selectionAnchor = items.first?.id
    }
}
