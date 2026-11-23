import CoreGraphics
import Testing
@testable import Ittan

@Suite("Shelf grid layout")
struct ShelfGridLayoutTests {
    @Test("The shelf is one fixed column")
    func singleColumnPanel() {
        #expect(
            ShelfLayoutMetrics.panelWidth
                == ShelfLayoutMetrics.cardSize.width + ShelfLayoutMetrics.contentInset * 2
        )
        #expect(ShelfDimensions.minimum.width == ShelfLayoutMetrics.panelWidth)
        #expect(ShelfDimensions.default.width == ShelfDimensions.minimum.width)
        #expect(
            ShelfDimensions(width: 378, height: 480).displayed().width
                == ShelfDimensions.minimum.width
        )
        #expect(
            ShelfDimensions(width: 378, height: 40).displayed().height
                == ShelfDimensions.minimum.height
        )
    }

    @Test("Reorder follows a single column from top to bottom")
    func singleColumnReorder() {
        let card = ShelfLayoutMetrics.cardSize
        let spacing = ShelfLayoutMetrics.cardSpacing
        let inset = ShelfLayoutMetrics.contentInset
        let rowStep = card.height + spacing
        let centerX = inset + card.width / 2

        #expect(ShelfGridLayout.reorderDestinationIndex(
            pointFromTopLeading: CGPoint(x: centerX, y: inset + card.height / 2),
            itemCount: 4,
            columnCount: 1,
            contentInset: inset,
            cardSize: card,
            spacing: spacing
        ) == 0)
        #expect(ShelfGridLayout.reorderDestinationIndex(
            pointFromTopLeading: CGPoint(x: centerX, y: inset + rowStep + 1),
            itemCount: 4,
            columnCount: 1,
            contentInset: inset,
            cardSize: card,
            spacing: spacing
        ) == 1)
    }
}
