import AppKit
import SwiftUI

@MainActor
final class ShelfPanelController {
    static let shared = ShelfPanelController()

    private let panelWidth: CGFloat = 162
    // ShelfView's fixed card width keeps the hosting view at 148 points even
    // while its visible content is the narrow tab. Use that real width when
    // anchoring the collapsed panel so the right edge does not drift off-screen.
    private let collapsedPanelSize = NSSize(width: 148, height: 80)
    private let itemHeight: CGFloat = 102
    private let emptyHeight: CGFloat = 104
    private let undoToastHeight: CGFloat = 41
    private let maximumVisibleItems = 5
    private let edgeMargin: CGFloat = 0
    private var panel: ShelfPanel?
    private var isCollapsed = false
    private var expandedShelfHeight: CGFloat = 104
    private var expandedPanelSize = NSSize(width: 162, height: 104)
    private var isUndoToastVisible = false
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

    func preferencesDidChange() {
        guard let panel,
              let screen = panel.screen ?? ScreenResolver.screenUnderPointer() else { return }
        position(panel, on: screen, animated: true)
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
            guard let self, !self.isCollapsed else { return }
            let closesTowardEdge = IttanPreferences.shelfSide == .left ? delta < 0 : delta > 0
            guard closesTowardEdge else { return }
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
        expandedShelfHeight = shelfHeight
        isUndoToastVisible = hasUndoNotice
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
        let targetOriginY = isCollapsed
            ? screenFrame.midY - targetSize.height / 2
            : screenFrame.midY
                - expandedShelfHeight / 2
                - (isUndoToastVisible ? undoToastHeight : 0)
        let origin = NSPoint(
            x: IttanPreferences.shelfSide == .left
                ? screenFrame.minX + edgeMargin
                : screenFrame.maxX - targetSize.width - edgeMargin,
            y: targetOriginY
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
    private weak var autoScrollView: NSScrollView?
    private var autoScrollTimer: Timer?
    private var autoScrollVelocity: CGFloat = 0
    private var lastInternalDragPoint: NSPoint?
    private var lastInternalDragIDs: [ShelfItem.ID] = []
    private var lastDragIsExternal = false

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
        let isInsideTabHorizontally = IttanPreferences.shelfSide == .left
            ? local.x <= 78
            : local.x >= bounds.maxX - 78
        if isInsideTabHorizontally,
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
        if sender.draggingSource is FileDragSourceView {
            IttanStore.shelf.send(.setDropTargeted(false))
            return .move
        }
        guard PasteboardImporter.canImport(sender.draggingPasteboard) else { return [] }
        IttanStore.shelf.send(.setDropTargeted(true))
        lastDragIsExternal = true
        lastInternalDragPoint = sender.draggingLocation
        updateExternalDropPreview(at: sender.draggingLocation)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let windowPoint = sender.draggingLocation
        lastInternalDragPoint = windowPoint
        updateAutoScrollState(at: windowPoint)
        if let source = sender.draggingSource as? FileDragSourceView {
            lastDragIsExternal = false
            lastInternalDragIDs = source.draggedIDs
            updateReorderPreview(at: windowPoint, draggedIDs: source.draggedIDs)
            return .move
        }
        guard PasteboardImporter.canImport(sender.draggingPasteboard) else { return [] }
        lastDragIsExternal = true
        lastInternalDragIDs = []
        updateExternalDropPreview(at: windowPoint)
        return .copy
    }

    private func updateReorderPreview(at windowPoint: NSPoint, draggedIDs: [ShelfItem.ID]) {
        if let target = closestItemView(to: windowPoint, excluding: Set(draggedIDs)) {
            let point = target.convert(windowPoint, from: nil)
            let placement: ShelfItemDropPlacement = point.y >= target.bounds.midY
                ? .before
                : .after
            IttanStore.shelf.send(
                .previewReorder(draggedIDs, relativeTo: target.item.id, placement)
            )
        } else {
            IttanStore.shelf.send(.previewReorder(draggedIDs, relativeTo: nil, .before))
        }
    }

    private func updateExternalDropPreview(at windowPoint: NSPoint) {
        if let target = closestItemView(to: windowPoint, excluding: []) {
            let point = target.convert(windowPoint, from: nil)
            let placement: ShelfItemDropPlacement = point.y >= target.bounds.midY
                ? .before
                : .after
            IttanStore.shelf.send(
                .previewExternalDrop(relativeTo: target.item.id, placement)
            )
        } else {
            IttanStore.shelf.send(.previewExternalDrop(relativeTo: nil, .before))
        }
    }

    private func updateAutoScrollState(at windowPoint: NSPoint) {
        guard let scrollView = descendantScrollView(in: self) else {
            stopAutoScroll()
            return
        }
        let clipView = scrollView.contentView
        let point = clipView.convert(windowPoint, from: nil)
        let visibleBounds = clipView.bounds
        let threshold: CGFloat = 44
        let topDistance: CGFloat
        let bottomDistance: CGFloat

        if clipView.isFlipped {
            topDistance = point.y - visibleBounds.minY
            bottomDistance = visibleBounds.maxY - point.y
        } else {
            topDistance = visibleBounds.maxY - point.y
            bottomDistance = point.y - visibleBounds.minY
        }

        let direction: CGFloat
        let distance: CGFloat
        if topDistance < threshold {
            direction = clipView.isFlipped ? -1 : 1
            distance = topDistance
        } else if bottomDistance < threshold {
            direction = clipView.isFlipped ? 1 : -1
            distance = bottomDistance
        } else {
            stopAutoScroll()
            return
        }

        let proximity = 1 - min(max(distance, 0), threshold) / threshold
        autoScrollVelocity = direction * (1.5 + proximity * 6.5)
        autoScrollView = scrollView
        startAutoScroll()
    }

    private func startAutoScroll() {
        guard autoScrollTimer == nil else { return }
        let timer = Timer(
            timeInterval: 1 / 60,
            target: self,
            selector: #selector(performAutoScrollStep),
            userInfo: nil,
            repeats: true
        )
        autoScrollTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
        autoScrollView = nil
        autoScrollVelocity = 0
    }

    @objc private func performAutoScrollStep() {
        guard let scrollView = autoScrollView,
              let documentView = scrollView.documentView else {
            stopAutoScroll()
            return
        }
        let clipView = scrollView.contentView
        let visibleBounds = clipView.bounds
        let minimumY = documentView.bounds.minY
        let maximumY = max(minimumY, documentView.bounds.maxY - visibleBounds.height)
        let destinationY = min(
            max(visibleBounds.origin.y + autoScrollVelocity, minimumY),
            maximumY
        )
        guard destinationY != visibleBounds.origin.y else {
            stopAutoScroll()
            return
        }
        clipView.scroll(to: NSPoint(x: visibleBounds.origin.x, y: destinationY))
        scrollView.reflectScrolledClipView(clipView)
        if let point = lastInternalDragPoint {
            if lastDragIsExternal {
                updateExternalDropPreview(at: point)
            } else if !lastInternalDragIDs.isEmpty {
                updateReorderPreview(at: point, draggedIDs: lastInternalDragIDs)
            }
        }
    }

    private func closestItemView(
        to windowPoint: NSPoint,
        excluding draggedIDs: Set<ShelfItem.ID>
    ) -> FileDragSourceView? {
        descendantItemViews(in: self)
            .filter { !draggedIDs.contains($0.item.id) }
            .min { lhs, rhs in
                verticalDistance(from: windowPoint, to: lhs)
                    < verticalDistance(from: windowPoint, to: rhs)
            }
    }

    private func descendantItemViews(in view: NSView) -> [FileDragSourceView] {
        view.subviews.flatMap { subview in
            let current = (subview as? FileDragSourceView).map { [$0] } ?? []
            return current + descendantItemViews(in: subview)
        }
    }

    private func descendantScrollView(in view: NSView) -> NSScrollView? {
        for subview in view.subviews {
            if let scrollView = subview as? NSScrollView { return scrollView }
            if let scrollView = descendantScrollView(in: subview) { return scrollView }
        }
        return nil
    }

    private func verticalDistance(from windowPoint: NSPoint, to view: NSView) -> CGFloat {
        let point = view.convert(windowPoint, from: nil)
        if point.y < view.bounds.minY { return view.bounds.minY - point.y }
        if point.y > view.bounds.maxY { return point.y - view.bounds.maxY }
        return 0
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        stopAutoScroll()
        IttanStore.shelf.send(.setDropTargeted(false))
        if sender?.draggingSource is FileDragSourceView {
            IttanStore.shelf.send(.cancelReorder)
        } else {
            IttanStore.shelf.send(.cancelExternalDropPreview)
        }
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        stopAutoScroll()
        IttanStore.shelf.send(.setDropTargeted(false))
        IttanStore.shelf.send(.cancelExternalDropPreview)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        stopAutoScroll()
        IttanStore.shelf.send(.setDropTargeted(false))
        if sender.draggingSource is FileDragSourceView {
            IttanStore.shelf.send(.commitReorder)
            return true
        }
        let insertionIndex = IttanStore.shelf.externalDropInsertionIndex
            ?? IttanStore.shelf.items.endIndex
        IttanStore.shelf.send(.cancelExternalDropPreview)
        let imported = PasteboardImporter.importItems(from: sender.draggingPasteboard) { urls in
            IttanStore.shelf.send(.addURLsAt(urls, insertionIndex))
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
            let contentBounds = contentView?.bounds ?? .zero
            let isInsideTabHorizontally = IttanPreferences.shelfSide == .left
                ? point.x <= 78
                : point.x >= contentBounds.maxX - 78
            if isInsideTabHorizontally, point.y >= tabMinY, point.y <= tabMaxY {
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
