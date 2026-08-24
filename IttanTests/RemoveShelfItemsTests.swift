import Foundation
import Testing
@testable import Ittan

@Suite("Remove shelf items")
struct RemoveShelfItemsTests {
    @Test("Removal history respects its configured limit")
    func historyLimit() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("IttanRemoveTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let items = try (0..<4).map { index in
            let url = root.appendingPathComponent("\(index).txt")
            try Data().write(to: url)
            return ShelfItem(url: url)
        }
        var history = Array(items.prefix(3))
        var lastRemovedBatch: [ShelfItem] = []
        var notice: UndoNotice?

        RemoveShelfItems.record(
            [items[3]],
            history: &history,
            lastRemovedBatch: &lastRemovedBatch,
            undoNotice: &notice,
            noticeID: UUID(),
            historyLimit: 2
        )

        #expect(history == [items[3], items[0]])
        #expect(lastRemovedBatch == [items[3]])
        #expect(notice != nil)
    }
}
