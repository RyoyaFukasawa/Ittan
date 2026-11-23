import AppKit
import ComposableArchitecture
import SwiftUI

@MainActor
final class NewShelfDropTargetController {
    static let shared = NewShelfDropTargetController(store: IttanStore.workspace)

    private let size = NSSize(width: 116, height: 42)
    private let store: StoreOf<ShelfWorkspaceFeature>
    private var panel: NSPanel?
    private var latestPointer = CGPoint.zero

    init(store: StoreOf<ShelfWorkspaceFeature>) {
        self.store = store
    }

    func show(at pointer: CGPoint) {
        latestPointer = pointer
        let panel = panel ?? makePanel()
        position(panel, at: pointer)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
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
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = NewShelfDropHostingView(
            rootView: NewShelfDropTargetView(),
            onDrop: { [weak self] urls in self?.createShelf(urls: urls) }
        )
        self.panel = panel
        return panel
    }

    private func position(_ panel: NSPanel, at pointer: CGPoint) {
        panel.setFrameOrigin(
            CGPoint(x: pointer.x - size.width / 2, y: pointer.y - size.height / 2)
        )
    }

    private func createShelf(urls: [URL]) {
        guard !urls.isEmpty,
              let screen = NSScreen.screens.first(where: { $0.frame.contains(latestPointer) })
                ?? NSScreen.main else { return }
        let placement = ShelfAppearance.placement(
            edge: IttanPreferences.shelfEdge,
            dimensions: ShelfDimensions.default.displayed(),
            screenID: ScreenResolver.identifier(for: screen),
            screenFrame: screen.frame
        )
        store.send(.createShelf(urls: urls, placement: placement))
        hide()
    }
}

private struct NewShelfDropTargetView: View {
    var body: some View {
        Label("New Shelf", systemImage: "plus")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: 108, height: 34)
            .glassEffect(.regular.interactive(), in: Capsule())
            .overlay {
                Capsule().strokeBorder(.primary.opacity(0.18), lineWidth: 1)
            }
            .padding(4)
    }
}

@MainActor
private final class NewShelfDropHostingView: NSHostingView<NewShelfDropTargetView> {
    private let onDrop: ([URL]) -> Void

    init(rootView: NewShelfDropTargetView, onDrop: @escaping ([URL]) -> Void) {
        self.onDrop = onDrop
        super.init(rootView: rootView)
        registerForDraggedTypes(PasteboardImporter.acceptedTypes)
    }

    @available(*, unavailable)
    required init(rootView: NewShelfDropTargetView) {
        fatalError("Use init(rootView:onDrop:)")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        PasteboardImporter.canImport(sender.draggingPasteboard) ? .copy : []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        PasteboardImporter.canImport(sender.draggingPasteboard) ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        PasteboardImporter.importItems(from: sender.draggingPasteboard) { [onDrop] urls in
            onDrop(urls)
        }
    }
}
