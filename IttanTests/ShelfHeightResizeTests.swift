import CoreGraphics
import Testing
@testable import Ittan

@Suite("Shelf height resize")
struct ShelfHeightResizeTests {
    private let minimum: CGFloat = 158
    private let rowStep: CGFloat = 102

    @Test("Dragging the bottom grip down lengthens the centered shelf")
    func dragDownGrowsHeight() {
        let height = ShelfHeightResize.height(
            initialHeight: 320,
            cursorDeltaY: -20,
            minimumHeight: minimum,
            screenHeight: 900
        )
        #expect(height == 360)
    }

    @Test("A short screen limits the live height")
    func screenLimitsLiveHeight() {
        let height = ShelfHeightResize.height(
            initialHeight: 320,
            cursorDeltaY: -400,
            minimumHeight: minimum,
            screenHeight: 500
        )
        #expect(height == 500)
    }

    @Test("Snapping stays within the current screen")
    func snapStaysInsideScreen() {
        let height = ShelfHeightResize.snapped(
            proposedHeight: 900,
            minimumHeight: minimum,
            maximumHeight: 900,
            rowStep: rowStep
        )
        #expect(height <= 900)
        #expect(height == 872)
    }

    @Test("A screen shorter than one card uses the screen height")
    func tinyScreenUsesScreenHeight() {
        let height = ShelfHeightResize.snapped(
            proposedHeight: 158,
            minimumHeight: minimum,
            maximumHeight: 100,
            rowStep: rowStep
        )
        #expect(height == 100)
    }

    @Test("Reaching the laptop edge keeps a taller preferred height")
    func blockedGrowthKeepsPreferredHeight() {
        let height = ShelfHeightResize.committedHeight(
            liveHeight: 800,
            preferredHeight: 1_200,
            dragStartHeight: 600,
            minimumHeight: minimum,
            screenHeight: 800,
            rowStep: rowStep
        )
        #expect(height == 1_200)
    }

    @Test("A click on the grip keeps the current height")
    func unchangedDragKeepsPreferredHeight() {
        let height = ShelfHeightResize.committedHeight(
            liveHeight: 320,
            preferredHeight: 320,
            dragStartHeight: 320,
            minimumHeight: minimum,
            screenHeight: 900,
            rowStep: rowStep
        )
        #expect(height == 320)
    }

    @Test("Shrinking on a laptop replaces the preferred height")
    func shrinkingCommitsTheNewHeight() {
        let height = ShelfHeightResize.committedHeight(
            liveHeight: 500,
            preferredHeight: 1_200,
            dragStartHeight: 800,
            minimumHeight: minimum,
            screenHeight: 800,
            rowStep: rowStep
        )
        #expect(height < 1_200)
        #expect(height <= 800)
        #expect(height >= minimum)
    }

    @Test("The grip sits outside the shelf glass")
    func handleSitsOutsideTheGlass() {
        let glass = CGSize(width: 164, height: 320)
        let window = ShelfResizeHandleLayout.windowSize(forGlass: glass)
        let bounds = CGRect(origin: .zero, size: window)

        for edge in [ShelfEdge.left, ShelfEdge.right] {
            let glassFrame = ShelfResizeHandleLayout.glassFrame(
                in: bounds,
                edge: edge,
                showsGutter: true
            )
            let handle = ShelfResizeHandleLayout.frame(in: bounds, edge: edge)

            #expect(glassFrame.size == glass)
            #expect(handle.minY < glassFrame.minY)
            #expect(handle.width == ShelfResizeHandleLayout.side)
            if edge == .left {
                #expect(glassFrame.minX == bounds.minX)
                #expect(handle.maxX == bounds.maxX)
                #expect(handle.maxX > glassFrame.maxX)
            } else {
                #expect(glassFrame.maxX == bounds.maxX)
                #expect(handle.minX == bounds.minX)
                #expect(handle.minX < glassFrame.minX)
            }
        }
    }

    @Test("The handle is the corner curve")
    func handleCurveFollowsTheCorner() {
        let bounds = CGRect(x: 0, y: 0, width: 28, height: 28)
        let left = ShelfResizeHandleGeometry.curve(in: bounds, edge: .left)
        let right = ShelfResizeHandleGeometry.curve(in: bounds, edge: .right)

        #expect(left.start == CGPoint(x: 9, y: 5))
        #expect(left.control1 == CGPoint(x: 17, y: 5))
        #expect(left.control2 == CGPoint(x: 23, y: 11))
        #expect(left.end == CGPoint(x: 23, y: 19))
        #expect(right.start.x == bounds.maxX - left.start.x)
        #expect(right.end.x == bounds.maxX - left.end.x)
        #expect(right.start.y == left.start.y)
        #expect(right.end.y == left.end.y)
    }
}
