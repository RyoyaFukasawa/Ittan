import AppKit

/// A full-width hairline shown while a vertical shelf drag is stuck to the screen center.
@MainActor
final class ShelfCenterGuide {
    private var panel: NSPanel?

    var isVisible: Bool {
        panel?.isVisible == true
    }

    func show(on screen: NSScreen, midY: CGFloat) {
        let panel = panel ?? makePanel()
        self.panel = panel
        let appearing = !panel.isVisible
        panel.setFrame(
            ShelfCenterSnap.guideFrame(
                screenFrame: screen.frame,
                midY: midY,
                scale: screen.backingScaleFactor
            ),
            display: true
        )
        if appearing {
            panel.orderFrontRegardless()
        }
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = NSColor(srgbRed: 1, green: 0, blue: 1, alpha: 1)
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .floating
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle,
        ]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        return panel
    }
}
