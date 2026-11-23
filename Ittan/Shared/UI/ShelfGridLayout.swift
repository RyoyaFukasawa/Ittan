import CoreGraphics

enum ShelfGridLayout {
    static func reorderDestinationIndex(
        pointFromTopLeading point: CGPoint,
        itemCount: Int,
        columnCount: Int,
        contentInset: CGFloat,
        cardSize: CGSize,
        spacing: CGFloat
    ) -> Int {
        guard itemCount > 0 else { return 0 }
        let columnCount = max(columnCount, 1)
        let columnStep = cardSize.width + spacing
        let rowStep = cardSize.height + spacing
        let column = min(max(Int(
            ((point.x - contentInset - cardSize.width / 2) / columnStep).rounded()
        ), 0), columnCount - 1)
        let maximumRow = max((itemCount - 1) / columnCount, 0)
        let row = min(max(Int(
            ((point.y - contentInset - cardSize.height / 2) / rowStep).rounded()
        ), 0), maximumRow)
        return min(row * columnCount + column, itemCount - 1)
    }
}
