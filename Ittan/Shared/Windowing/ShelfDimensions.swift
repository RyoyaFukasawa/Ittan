import CoreGraphics

struct ShelfDimensions: Codable, Equatable, Sendable {
    var width: CGFloat
    var height: CGFloat

    static let minimum = Self(
        width: ShelfLayoutMetrics.minimumPanelSize.width,
        height: ShelfLayoutMetrics.minimumPanelSize.height
    )
    static let `default` = Self(width: minimum.width, height: 320)

    /// The shelf stays one column at the pre-Yoink card width.
    func displayed() -> Self {
        Self(
            width: ShelfLayoutMetrics.panelWidth,
            height: max(height, ShelfLayoutMetrics.minimumPanelSize.height)
        )
    }
    var size: CGSize { CGSize(width: width, height: height) }
}
