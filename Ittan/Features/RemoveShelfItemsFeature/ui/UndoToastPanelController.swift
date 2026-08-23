import AppKit
import SwiftUI

@MainActor
final class UndoToastPanelController {
    static let shared = UndoToastPanelController()

    private let size = NSSize(width: 142, height: 34)
    private var panel: NSPanel?

    private init() {}

    func update(notice: UndoNotice?) {
        guard let notice else {
            panel?.orderOut(nil)
            return
        }

        let panel = panel ?? makePanel()
        let hosting = NSHostingView(rootView: UndoToastView(notice: notice))
        hosting.frame = NSRect(origin: .zero, size: size)
        panel.contentView = hosting
        reposition()
        panel.orderFrontRegardless()
    }

    func reposition() {
        guard let panel,
              let anchor = ShelfPanelController.shared.auxiliaryAnchorFrame else {
            panel?.orderOut(nil)
            return
        }
        panel.setFrameOrigin(
            NSPoint(
                x: anchor.minX + 14,
                y: anchor.minY - size.height - 7
            )
        )
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.panel = panel
        return panel
    }
}

private struct UndoToastView: View {
    let notice: UndoNotice

    var body: some View {
        HStack(spacing: 7) {
            Text(notice.message)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 2)

            Button("Undo") {
                IttanStore.shelf.send(.undoButtonTapped)
            }
            .buttonStyle(.plain)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, 10)
        .frame(width: 142, height: 32)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        .padding(.vertical, 1)
    }
}
