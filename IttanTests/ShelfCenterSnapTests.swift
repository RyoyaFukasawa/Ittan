import CoreGraphics
import Testing
@testable import Ittan

@Suite("Shelf center snap")
struct ShelfCenterSnapTests {
    @Test("A drag within 6pt of center sticks there")
    func sticksWithinTheThreshold() {
        let above = ShelfCenterSnap.decide(proposedMidY: 456, centerMidY: 450)
        let below = ShelfCenterSnap.decide(proposedMidY: 444, centerMidY: 450)
        let exact = ShelfCenterSnap.decide(proposedMidY: 450, centerMidY: 450)

        #expect(above == ShelfCenterSnap.Decision(midY: 450, isSnapped: true))
        #expect(below == ShelfCenterSnap.Decision(midY: 450, isSnapped: true))
        #expect(exact.isSnapped)
    }

    @Test("A drag past 6pt follows the pointer")
    func releasesPastTheThreshold() {
        let decision = ShelfCenterSnap.decide(proposedMidY: 456.1, centerMidY: 450)

        #expect(decision == ShelfCenterSnap.Decision(midY: 456.1, isSnapped: false))
    }

    @Test("The guide is a hairline across the screen")
    func guideSpansTheScreenAtTheCenter() {
        let screen = CGRect(x: 1_440, y: -200, width: 1_440, height: 900)
        let midY: CGFloat = 250.3
        let frame = ShelfCenterSnap.guideFrame(screenFrame: screen, midY: midY, scale: 2)

        #expect(frame.minX == screen.minX)
        #expect(frame.width == screen.width)
        #expect(frame.height == 0.5)
        #expect(frame.minY == 250)
        #expect(frame.minY <= midY)
        #expect(frame.maxY >= midY)
    }
}
