import SwiftUI

enum CornerControlsCorner: Sendable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing

    fileprivate func insets(_ value: CGFloat) -> EdgeInsets {
        EdgeInsets(
            top: self == .topLeading || self == .topTrailing ? value : 0,
            leading: self == .topLeading || self == .bottomLeading ? value : 0,
            bottom: self == .bottomLeading || self == .bottomTrailing ? value : 0,
            trailing: self == .topTrailing || self == .bottomTrailing ? value : 0
        )
    }
}

struct CornerControlsLayout<Content: View>: View {
    let corner: CornerControlsCorner
    let inset: CGFloat
    @ViewBuilder let content: Content

    init(
        _ corner: CornerControlsCorner,
        inset: CGFloat = 8,
        @ViewBuilder content: () -> Content
    ) {
        self.corner = corner
        self.inset = inset
        self.content = content()
    }

    var body: some View {
        ZStack {
            content
        }
        .padding(corner.insets(inset))
    }
}
