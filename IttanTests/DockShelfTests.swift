import Foundation
import Testing
@testable import Ittan

@Suite("Dock shelf")
struct DockShelfTests {
    @Test("Docking a second shelf assigns non-overlapping ordered slots")
    func resolvesCollisions() throws {
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        var shelves = [
            makeShelf(id: firstID, midpoint: 0.45),
            makeShelf(id: secondID, midpoint: nil),
        ]
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)

        let applied = DockShelf.apply(
            id: secondID,
            edge: .left,
            preferredMidY: 430,
            screenID: "main",
            screenFrame: screen,
            spacing: 12,
            shelves: &shelves
        )

        #expect(applied)
        let placements = shelves.map { shelf -> (CGFloat, CGFloat, Int) in
            guard case let .docked(_, _, normalizedMidY, _, order) = shelf.placement else {
                Issue.record("Expected a docked placement")
                return (0, 0, 0)
            }
            return (normalizedMidY * screen.height, DockShelf.height(for: shelf), order)
        }
        let first = placements[0]
        let second = placements[1]
        #expect(first.0 + first.1 / 2 + 12 <= second.0 - second.1 / 2)
        #expect(first.2 == 0)
        #expect(second.2 == 1)
    }

    @Test("A shelf stays floating when all dock slots cannot fit")
    func rejectsOverflow() {
        let firstID = UUID()
        let secondID = UUID()
        let floating = ShelfPlacement.floating(
            screenID: "main",
            normalizedFrame: CGRect(x: 0.4, y: 0.2, width: 0.2, height: 0.6)
        )
        var shelves = [
            makeShelf(id: firstID, midpoint: 0.4, itemCount: 5),
            ShelfFeature.State(id: secondID, items: [], placement: floating),
        ]

        let applied = DockShelf.apply(
            id: secondID,
            edge: .left,
            preferredMidY: 100,
            screenID: "main",
            screenFrame: CGRect(x: 0, y: 0, width: 1_440, height: 300),
            spacing: 12,
            shelves: &shelves
        )

        #expect(!applied)
        #expect(shelves[1].placement == floating)
    }

    private func makeShelf(
        id: UUID,
        midpoint: CGFloat?,
        itemCount: Int = 1
    ) -> ShelfFeature.State {
        let items = (0..<itemCount).map { index in
            ShelfItem(url: URL(fileURLWithPath: "/tmp/item-\(id)-\(index)"))
        }
        let placement: ShelfPlacement = midpoint.map {
            .docked(
                screenID: "main",
                edge: .left,
                normalizedMidY: $0,
                isCollapsed: false,
                order: 0
            )
        } ?? .floating(
            screenID: "main",
            normalizedFrame: CGRect(x: 0.4, y: 0.2, width: 0.2, height: 0.5)
        )
        return ShelfFeature.State(id: id, items: items, placement: placement)
    }
}
