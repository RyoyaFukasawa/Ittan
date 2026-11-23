import CoreGraphics
import Testing
@testable import Ittan

@Suite("Shelf appearance")
struct ShelfAppearanceTests {
    private let dimensions = ShelfDimensions(width: 164, height: 276)

    @Test("Right edge pins the shelf to the screen edge")
    func rightEdge() {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let placement = ShelfAppearance.placement(
            edge: .right,
            dimensions: dimensions,
            screenID: "main",
            screenFrame: screen
        )
        let frame = ShelfPlacementGeometry.restoredFrame(
            placement.normalizedFrame,
            dimensions: dimensions,
            in: screen
        )

        #expect(frame.maxX == screen.maxX)
        #expect(frame.minX == screen.maxX - dimensions.width)
        #expect(abs(frame.midY - screen.midY) < 0.5)
        #expect(frame.size == dimensions.size)
    }

    @Test("Left edge pins the shelf to the opposite edge")
    func leftEdge() {
        let screen = CGRect(x: 1_440, y: -200, width: 800, height: 600)
        let placement = ShelfAppearance.placement(
            edge: .left,
            dimensions: dimensions,
            screenID: "side",
            screenFrame: screen
        )
        let frame = ShelfPlacementGeometry.restoredFrame(
            placement.normalizedFrame,
            dimensions: dimensions,
            in: screen
        )

        #expect(frame.minX == screen.minX)
        #expect(abs(frame.midY - screen.midY) < 0.5)
        #expect(placement.screenID == "side")
    }

    @Test("A tall shelf moves inside the menu bar and Dock")
    func tallShelfStaysInTheUsableArea() {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let visible = CGRect(x: 0, y: 80, width: 1_440, height: 788)
        let frame = ShelfAppearance.frame(
            edge: .right,
            dimensions: ShelfDimensions(width: 164, height: 1_200),
            screenFrame: screen,
            visibleFrame: visible
        )

        #expect(frame.height == visible.height)
        #expect(frame.minY == visible.minY)
        #expect(frame.maxY == visible.maxY)
        #expect(frame.maxX == screen.maxX)
    }

    @Test("A short shelf stays centered on the physical screen")
    func shortShelfStaysCenteredWhenItFits() {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let visible = CGRect(x: 0, y: 80, width: 1_440, height: 788)
        let frame = ShelfAppearance.frame(
            edge: .left,
            dimensions: ShelfDimensions(width: 164, height: 320),
            screenFrame: screen,
            visibleFrame: visible
        )

        #expect(frame.height == 320)
        #expect(frame.minX == screen.minX)
        #expect(abs(frame.midY - screen.midY) < 0.5)
    }

    @Test("A vertical drag stays on the screen edge")
    func verticalDragStaysOnTheEdge() {
        let screen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let visible = CGRect(x: 0, y: 80, width: 1_440, height: 788)
        let raised = ShelfAppearance.frame(
            edge: .right,
            dimensions: ShelfDimensions(width: 178, height: 334),
            screenFrame: screen,
            visibleFrame: visible,
            normalizedMidY: 0.75
        )

        #expect(raised.maxX == screen.maxX)
        #expect(abs(raised.midY - screen.height * 0.75) < 0.5)

        let lowered = ShelfAppearance.frame(
            edge: .left,
            dimensions: ShelfDimensions(width: 178, height: 334),
            screenFrame: screen,
            visibleFrame: visible,
            normalizedMidY: 0.02
        )

        #expect(lowered.minX == screen.minX)
        #expect(lowered.minY >= visible.minY)
        #expect(lowered.maxY <= visible.maxY)
    }
}

private extension ShelfPlacement {
    var normalizedFrame: CGRect {
        guard case let .floating(_, normalizedFrame) = self else {
            Issue.record("Expected a floating shelf")
            return .zero
        }
        return normalizedFrame
    }
}
