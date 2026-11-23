import CoreGraphics
import Testing
@testable import Ittan

@Suite("Shelf window drag hit policy")
struct ShelfWindowDragHitPolicyTests {
    @Test("Dragging an item does not move its Shelf window")
    func itemDragWins() {
        let itemFrames = [CGRect(x: 32, y: 80, width: 100, height: 94)]

        #expect(!ShelfWindowDragHitPolicy.shouldMoveShelf(
            from: CGPoint(x: 82, y: 127),
            interactiveFrames: itemFrames
        ))
    }

    @Test("Dragging empty Shelf background moves the Shelf window")
    func backgroundDragWins() {
        let itemFrames = [CGRect(x: 32, y: 80, width: 100, height: 94)]

        #expect(ShelfWindowDragHitPolicy.shouldMoveShelf(
            from: CGPoint(x: 150, y: 220),
            interactiveFrames: itemFrames
        ))
    }

    @Test("Dragging the resize handle does not move the Shelf window")
    func resizeHandleWins() {
        let resizeHandleFrame = CGRect(x: 160, y: 0, width: 18, height: 18)

        #expect(!ShelfWindowDragHitPolicy.shouldMoveShelf(
            from: CGPoint(x: 169, y: 9),
            interactiveFrames: [resizeHandleFrame]
        ))
    }
}
