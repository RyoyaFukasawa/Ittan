import Foundation

enum RenameShelfItem {
    static func apply(
        id: ShelfItem.ID,
        proposedName: String,
        to items: inout [ShelfItem],
        rename: (URL, String) throws -> URL
    ) throws -> Bool {
        guard let index = items.firstIndex(where: { $0.id == id }),
              items[index].exists else { return false }
        let oldItem = items[index]
        let destination = try rename(oldItem.url, proposedName)
        items[index] = ShelfItem(
            id: oldItem.id,
            url: destination,
            addedAt: oldItem.addedAt,
            isLocked: oldItem.isLocked
        )
        return true
    }
}
