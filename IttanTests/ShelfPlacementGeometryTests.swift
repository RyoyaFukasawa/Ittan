import Foundation
import Testing
@testable import Ittan

@Suite("Shelf placement geometry")
struct ShelfPlacementGeometryTests {
    @Test("Resize completion preserves a floating frame's top-left anchor")
    func resizedFloatingPlacementPreservesFrame() throws {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let resizedFrame = CGRect(x: 300, y: 298, width: 270, height: 378)
        let original = ShelfPlacement.floating(
            screenID: "main",
            normalizedFrame: CGRect(x: 0.2, y: 0.4, width: 0.1, height: 0.2)
        )

        let updated = ShelfPlacementGeometry.placementAfterResize(
            original,
            frame: resizedFrame,
            screenID: "main",
            screenFrame: screen
        )
        guard case let .floating(_, normalizedFrame) = updated else {
            Issue.record("Expected floating placement")
            return
        }

        let restored = ShelfPlacementGeometry.restoredFrame(
            normalizedFrame,
            dimensions: ShelfDimensions(
                width: resizedFrame.width,
                height: resizedFrame.height
            ),
            in: screen
        )
        #expect(restored.isApproximatelyEqual(to: resizedFrame))
        #expect(restored.maxY == resizedFrame.maxY)
    }

    @Test("A floating frame survives normalization and restoration")
    func normalizedFrameRoundTrip() {
        let screen = CGRect(x: 100, y: 50, width: 1_200, height: 800)
        let frame = CGRect(x: 340, y: 250, width: 360, height: 480)

        let normalized = ShelfPlacementGeometry.normalizedFrame(frame, in: screen)
        let restored = ShelfPlacementGeometry.restoredFrame(normalized, in: screen)

        #expect(restored.isApproximatelyEqual(to: frame))
    }

    @Test("Oversized saved dimensions restore inside the current screen")
    func oversizedDimensionsAreClampedOnRestore() {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let savedPlacement = CGRect(x: 0.7, y: 0.2, width: 0.2, height: 0.5)
        let savedDimensions = ShelfDimensions(width: 2_000, height: 1_500)

        let restored = ShelfPlacementGeometry.restoredFrame(
            savedPlacement,
            dimensions: savedDimensions,
            in: screen
        )

        #expect(restored == screen)
        #expect(restored.width >= ShelfDimensions.minimum.width)
        #expect(restored.height >= ShelfDimensions.minimum.height)
    }

    @Test("Only the left and right screen edges are docking candidates")
    func leftAndRightDockCandidates() {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let left = CGRect(x: 18, y: 220, width: 320, height: 420)
        let right = CGRect(x: 1_102, y: 220, width: 320, height: 420)
        let top = CGRect(x: 560, y: 462, width: 320, height: 420)
        let middle = CGRect(x: 560, y: 220, width: 320, height: 420)

        #expect(ShelfPlacementGeometry.dockCandidate(for: left, screenFrame: screen, threshold: 24) == .left)
        #expect(ShelfPlacementGeometry.dockCandidate(for: right, screenFrame: screen, threshold: 24) == .right)
        #expect(ShelfPlacementGeometry.dockCandidate(for: top, screenFrame: screen, threshold: 24) == nil)
        #expect(ShelfPlacementGeometry.dockCandidate(for: middle, screenFrame: screen, threshold: 24) == nil)
    }

    @Test("Docked shelves are ordered by preference without overlapping")
    func dockSlotsDoNotOverlap() throws {
        let upperID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let lowerID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let requests = [
            ShelfDockRequest(id: lowerID, preferredMidY: 430, height: 300),
            ShelfDockRequest(id: upperID, preferredMidY: 360, height: 260),
        ]

        let result = try #require(
            ShelfPlacementGeometry.resolveDockSlots(
                requests,
                screenFrame: screen,
                spacing: 12
            )
        )

        #expect(result.map(\.id) == [upperID, lowerID])
        #expect(result[0].frame.maxY + 12 <= result[1].frame.minY)
        #expect(screen.contains(result[0].frame))
        #expect(screen.contains(result[1].frame))
    }

    @Test("Dock slots fail when the shelves cannot fit on screen")
    func dockSlotsRejectOverflow() {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 500)
        let requests = [
            ShelfDockRequest(id: UUID(), preferredMidY: 150, height: 300),
            ShelfDockRequest(id: UUID(), preferredMidY: 350, height: 300),
        ]

        #expect(
            ShelfPlacementGeometry.resolveDockSlots(
                requests,
                screenFrame: screen,
                spacing: 12
            ) == nil
        )
    }
}

private extension CGRect {
    func isApproximatelyEqual(to other: CGRect, tolerance: CGFloat = 0.001) -> Bool {
        abs(minX - other.minX) <= tolerance
            && abs(minY - other.minY) <= tolerance
            && abs(width - other.width) <= tolerance
            && abs(height - other.height) <= tolerance
    }
}
