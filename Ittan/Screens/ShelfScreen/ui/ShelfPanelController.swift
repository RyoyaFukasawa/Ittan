import AppKit
import SwiftUI

@MainActor
final class ShelfPanelController {
    static let shared = ShelfPanelController()

    private let panelWidth: CGFloat = 162
    private let collapsedPanelSize = NSSize(width: 80, height: 80)
    private let itemHeight: CGFloat = 102
    private let emptyHeight: CGFloat = 104
    private let undoToastHeight: CGFloat = 41
    private let maximumVisibleItems = 5
    private let edgeMargin: CGFloat = 0
    private var panel: ShelfPanel?
    private var isCollapsed = false
    private var expandedPanelSize = NSSize(width: 162, height: 104)
    private var pendingPanelResize: Task<Void, Never>?
    private var isTemporarilyExpandedForExternalDrag = false
    private var didAcceptCurrentExternalDrop = false

    private init() {}

    func show(on requestedScreen: NSScreen? = nil) {
        pendingPanelResize?.cancel()
        let panel = panel ?? makePanel()
        let screen = requestedScreen ?? panel.screen ?? ScreenResolver.screenUnderPointer()
        isCollapsed = false
        IttanStore.shelf.send(.setPanelCollapsed(false))
        panel.tabIsVisible = false
        panel.horizontalSwipeEnabled = true
        updateExpandedPanelSize(
            itemCount: IttanStore.shelf.items.count,
            hasUndoNotice: IttanStore.shelf.undoNotice != nil
        )

        position(panel, on: screen, animated: false)

        panel.orderFrontRegardless()
    }

    func externalDragStarted(on screen: NSScreen?) {
        let wasOpen = panel?.isVisible == true && !isCollapsed
        isTemporarilyExpandedForExternalDrag = !wasOpen
        didAcceptCurrentExternalDrop = false
        show(on: screen)
    }

    func externalDropAccepted() {
        didAcceptCurrentExternalDrop = true
    }

    func toggleCollapsed() {
        setCollapsed(!isCollapsed)
    }

    private func setCollapsed(_ collapsed: Bool) {
        guard collapsed != isCollapsed,
              let panel,
              let screen = panel.screen ?? ScreenResolver.screenUnderPointer() else { return }
        pendingPanelResize?.cancel()
        isCollapsed = collapsed
        panel.horizontalSwipeEnabled = !collapsed

        if collapsed {
            // Let SwiftUI finish sliding the shelf out before reducing the
            // actual window. Resizing both at once makes the glass appear to
            // collapse vertically.
            IttanStore.shelf.send(.setPanelCollapsed(true))
            panel.tabIsVisible = true
            pendingPanelResize = Task { @MainActor [weak self, weak panel, weak screen] in
                try? await Task.sleep(for: .milliseconds(320))
                guard !Task.isCancelled,
                      let self,
                      let panel,
                      self.isCollapsed else { return }
                self.position(panel, on: screen, animated: false)
            }
        } else {
            // Restore the full hit area while it is still visually empty,
            // then animate the shelf into that space.
            position(panel, on: screen, animated: false)
            IttanStore.shelf.send(.setPanelCollapsed(false))
            panel.tabIsVisible = false
        }
    }

    func layoutDidChange(_ items: [ShelfItem], hasUndoNotice: Bool) {
        guard let panel else {
            if !items.isEmpty { show() }
            return
        }

        updateExpandedPanelSize(itemCount: items.count, hasUndoNotice: hasUndoNotice)
        if !items.isEmpty,
           let screen = panel.screen ?? ScreenResolver.screenUnderPointer() {
            position(panel, on: screen, animated: panel.isVisible && !isCollapsed)
        }
        if items.isEmpty {
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    func externalDragEnded() {
        Task { @MainActor in
            // AppKit may report the global drag ending just before the local
            // destination finishes `performDragOperation`, so allow that
            // callback to record a successful Ittan drop first.
            try? await Task.sleep(for: .milliseconds(180))

            if isTemporarilyExpandedForExternalDrag,
               !didAcceptCurrentExternalDrop {
                setCollapsed(true)
            }

            isTemporarilyExpandedForExternalDrag = false
            didAcceptCurrentExternalDrop = false

            guard IttanStore.shelf.items.isEmpty else { return }
            try? await Task.sleep(for: .milliseconds(170))
            guard IttanStore.shelf.items.isEmpty else { return }
            panel?.orderOut(nil)
        }
    }

    private func makePanel() -> ShelfPanel {
        let panel = ShelfPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: emptyHeight),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.ignoresMouseEvents = false
        panel.hasShadow = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = false
        panel.level = .floating
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle,
        ]
        panel.onHorizontalSwipe = { [weak self] delta in
            guard let self, !self.isCollapsed, delta < 0 else { return }
            self.setCollapsed(true)
        }
        panel.onTabClick = { [weak self] in
            self?.toggleCollapsed()
        }

        let hostingView = ShelfHostingView(rootView: ShelfView())
        hostingView.sizingOptions = []
        hostingView.frame = panel.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView

        self.panel = panel
        return panel
    }

    private func updateExpandedPanelSize(itemCount: Int, hasUndoNotice: Bool) {
        let visibleItems = min(max(itemCount, 1), maximumVisibleItems)
        let shelfHeight = itemCount == 0
            ? emptyHeight
            : CGFloat(visibleItems) * itemHeight
                + (itemCount > maximumVisibleItems ? 96 : 72)
        expandedPanelSize = NSSize(
            width: panelWidth,
            height: shelfHeight + (hasUndoNotice ? undoToastHeight : 0)
        )
    }

    private func position(_ panel: NSPanel, on screen: NSScreen?, animated: Bool = false) {
        guard let screen else { return }
        // Match Screendrop's edge overlay: anchor the peek tab to the physical
        // screen frame, not visibleFrame (which is inset by the Dock/menu bar).
        let screenFrame = screen.frame
        let targetSize = isCollapsed ? collapsedPanelSize : expandedPanelSize
        let origin = NSPoint(
            x: screenFrame.minX + edgeMargin,
            y: screenFrame.midY - targetSize.height / 2
        )
        let targetFrame = NSRect(origin: origin, size: targetSize)
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.26
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                context.allowsImplicitAnimation = true
                panel.animator().setFrame(targetFrame, display: true)
            }
        } else {
            panel.setFrame(targetFrame, display: true, animate: false)
        }
    }

}

@MainActor
private final class ShelfHostingView: NSHostingView<ShelfView> {
    required init(rootView: ShelfView) {
        super.init(rootView: rootView)
        registerForDraggedTypes(PasteboardImporter.acceptedTypes)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard IttanStore.shelf.isPanelCollapsed else {
            return super.hitTest(point)
        }

        // AppKit supplies `point` in the superview's coordinate system.
        // Convert it exactly as Screendrop's passthrough hosting view does.
        let local = convert(point, from: superview)
        let tabMinY = bounds.midY - 40
        let tabMaxY = bounds.midY + 40
        if local.x <= 80,
           local.y >= tabMinY,
           local.y <= tabMaxY {
            return self
        }

        // The collapsed panel is mostly transparent. Match Screendrop's
        // passthrough overlay and let clicks outside the visible handle reach
        // the app underneath instead of activating Ittan's invisible window.
        return nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        let clear = NSMenuItem(title: "Clear Ittan", action: #selector(clearShelf), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)
        return menu
    }

    @objc private func clearShelf() {
        IttanStore.shelf.send(.clearButtonTapped)
    }


    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard PasteboardImporter.canImport(sender.draggingPasteboard) else { return [] }
        IttanStore.shelf.send(.setDropTargeted(true))
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        IttanStore.shelf.send(.setDropTargeted(false))
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        IttanStore.shelf.send(.setDropTargeted(false))
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        IttanStore.shelf.send(.setDropTargeted(false))
        let imported = PasteboardImporter.importItems(from: sender.draggingPasteboard) { urls in
            IttanStore.shelf.send(.addURLs(urls))
        }
        if imported {
            ShelfPanelController.shared.externalDropAccepted()
        }
        return imported
    }
}

private final class ShelfPanel: NSPanel {
    var onTabClick: (() -> Void)?
    var onHorizontalSwipe: ((CGFloat) -> Void)?
    var tabIsVisible = false
    var horizontalSwipeEnabled = true
    private var horizontalScroll: CGFloat = 0
    private var didTriggerSwipe = false

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if tabIsVisible, event.type == .leftMouseDown {
            let point = contentView?.convert(event.locationInWindow, from: nil) ?? .zero
            let tabMinY = (contentView?.bounds.midY ?? 0) - 40
            let tabMaxY = (contentView?.bounds.midY ?? 0) + 40
            if point.x <= 80, point.y >= tabMinY, point.y <= tabMaxY {
                onTabClick?()
                return
            }
        }
        if horizontalSwipeEnabled,
           event.type == .scrollWheel,
           event.hasPreciseScrollingDeltas,
           abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) * 1.2 {
            if event.phase == .began {
                horizontalScroll = 0
                didTriggerSwipe = false
            }
            horizontalScroll += event.scrollingDeltaX
            if !didTriggerSwipe, abs(horizontalScroll) >= 38 {
                didTriggerSwipe = true
                onHorizontalSwipe?(horizontalScroll)
            }
            if event.phase == .ended || event.phase == .cancelled {
                horizontalScroll = 0
                didTriggerSwipe = false
            }
            return
        }
        super.sendEvent(event)
    }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}
