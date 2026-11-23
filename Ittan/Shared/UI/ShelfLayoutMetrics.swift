import CoreGraphics

enum ShelfLayoutMetrics {
    static let cornerControlSize: CGFloat = 24
    static let cornerOuterPadding: CGFloat = 8
    static let contentInset = cornerControlSize + cornerOuterPadding
    static let cardSpacing: CGFloat = 8
    static let cardSize = CGSize(width: 100, height: 94)
    static let thumbnailSide: CGFloat = 64
    static let titleWidth: CGFloat = 92

    static let panelWidth = cardSize.width + contentInset * 2
    static let minimumPanelSize = CGSize(
        width: panelWidth,
        height: cardSize.height + contentInset * 2
    )
}
