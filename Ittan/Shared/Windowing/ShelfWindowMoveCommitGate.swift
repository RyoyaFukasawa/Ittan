import CoreGraphics

enum ShelfWindowMoveCommitGate {
    static func canCommit(pressedMouseButtons: Int) -> Bool {
        pressedMouseButtons & 1 == 0
    }

    static func canCommit(
        pressedMouseButtons: Int,
        hasSettled: Bool
    ) -> Bool {
        hasSettled && canCommit(pressedMouseButtons: pressedMouseButtons)
    }

    static func shouldApplyFrame(
        currentFrame: CGRect,
        targetFrame: CGRect,
        isMoving: Bool,
        isResizing: Bool
    ) -> Bool {
        guard !isMoving, !isResizing else { return false }
        let tolerance: CGFloat = 0.5
        return abs(currentFrame.minX - targetFrame.minX) > tolerance
            || abs(currentFrame.minY - targetFrame.minY) > tolerance
            || abs(currentFrame.width - targetFrame.width) > tolerance
            || abs(currentFrame.height - targetFrame.height) > tolerance
    }
}
