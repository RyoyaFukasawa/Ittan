import Testing
import CoreGraphics
@testable import Ittan

@Suite("Shelf window move commit gate")
struct ShelfWindowMoveCommitGateTests {
    @Test("A native window move is not committed while the mouse button is held")
    func waitsForMouseUp() {
        #expect(!ShelfWindowMoveCommitGate.canCommit(pressedMouseButtons: 1))
        #expect(ShelfWindowMoveCommitGate.canCommit(pressedMouseButtons: 0))
    }

    @Test("Mouse-up alone does not commit before the final move event settles")
    func waitsForFinalMoveToSettle() {
        #expect(
            !ShelfWindowMoveCommitGate.canCommit(
                pressedMouseButtons: 0,
                hasSettled: false
            )
        )
        #expect(
            ShelfWindowMoveCommitGate.canCommit(
                pressedMouseButtons: 0,
                hasSettled: true
            )
        )
    }

    @Test("An unchanged frame is not animated again")
    func skipsRedundantFrameUpdate() {
        let frame = CGRect(x: 100, y: 200, width: 162, height: 276)

        #expect(
            !ShelfWindowMoveCommitGate.shouldApplyFrame(
                currentFrame: frame,
                targetFrame: frame,
                isMoving: false,
                isResizing: false
            )
        )
    }

    @Test("No frame update can interrupt a native window move")
    func skipsFrameUpdateDuringMove() {
        #expect(
            !ShelfWindowMoveCommitGate.shouldApplyFrame(
                currentFrame: CGRect(x: 100, y: 200, width: 162, height: 276),
                targetFrame: CGRect(x: 500, y: 400, width: 162, height: 276),
                isMoving: true,
                isResizing: false
            )
        )
    }

    @Test("No frame update can interrupt a native window resize")
    func skipsFrameUpdateDuringResize() {
        #expect(
            !ShelfWindowMoveCommitGate.shouldApplyFrame(
                currentFrame: .zero,
                targetFrame: CGRect(x: 10, y: 10, width: 200, height: 200),
                isMoving: false,
                isResizing: true
            )
        )
    }

    @Test("A changed frame is applied while the window is idle")
    func appliesChangedFrameWhileIdle() {
        #expect(
            ShelfWindowMoveCommitGate.shouldApplyFrame(
                currentFrame: CGRect(x: 100, y: 200, width: 162, height: 276),
                targetFrame: CGRect(x: 500, y: 400, width: 162, height: 276),
                isMoving: false,
                isResizing: false
            )
        )
    }
}
