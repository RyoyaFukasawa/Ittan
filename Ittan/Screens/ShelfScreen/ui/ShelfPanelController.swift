import AppKit
import ComposableArchitecture
import SwiftUI

@MainActor
final class ShelfPanelController: NSObject, NSWindowDelegate {
    // Keep the collapsed window as wide as the shelf so the edge tab does not
    // drift when the shelf slides away.
    private var collapsedPanelSize: NSSize {
        NSSize(width: ShelfLayoutMetrics.panelWidth, height: 80)
    }
    private let edgeMargin: CGFloat = 0
    private var panel: ShelfPanel?
    private var isCollapsed = false
    private var expandedPanelSize = NSSize(
        width: ShelfDimensions.default.width,
        height: ShelfDimensions.default.height
    )
    private var pendingPanelResize: Task<Void, Never>?
    private var pendingMoveCommit: Task<Void, Never>?
    private var isTemporarilyExpandedForExternalDrag = false
    private var isPresentedForExternalDrag = false
    private var isHeldVisibleWhileEmpty = false
    private var presentationGeneration = 0
    private var lastItemCount = 0
    private var didAcceptCurrentExternalDrop = false
    private var isApplyingFrame = false
    private var isPerformingNativeMove = false
    private var isEdgeDragging = false
    private var edgeDragStartCursorY: CGFloat = 0
    private var edgeDragStartMidY: CGFloat = 0
    private var isPerformingNativeResize = false
    private var initialResizeHeight: CGFloat?
    private var initialResizeCursor: CGPoint?
    private var resizeScreenFrame: CGRect?
    private var resizeVisibleFrame: CGRect?
    private var resizeNormalizedMidY: CGFloat?
    private var resizeHandle: ShelfResizeHandleView?
    private let centerGuide = ShelfCenterGuide()
    private let store: StoreOf<ShelfFeature>
    private let onPlacementCommitted: (ShelfPlacement) -> Void
    private let onResizeCommitted: (ShelfDimensions, ShelfPlacement) -> Void
    private var placement: ShelfPlacement

    init(
        store: StoreOf<ShelfFeature>,
        placement: ShelfPlacement,
        onPlacementCommitted: @escaping (ShelfPlacement) -> Void,
        onResizeCommitted: @escaping (ShelfDimensions, ShelfPlacement) -> Void
    ) {
        self.store = store
        self.placement = placement
        self.onPlacementCommitted = onPlacementCommitted
        self.onResizeCommitted = onResizeCommitted
        if case let .docked(_, _, _, isCollapsed, _) = placement {
            self.isCollapsed = isCollapsed
        }
        super.init()
    }

    func holdVisibleWhileEmpty() {
        isHeldVisibleWhileEmpty = true
    }

    func show(on requestedScreen: NSScreen? = nil) {
        presentationGeneration += 1
        pendingPanelResize?.cancel()
        let needsInitialPosition = panel == nil
        let panel = panel ?? makePanel()
        let screen = requestedScreen ?? resolvedScreen(for: placement, panel: panel)
        panel.tabIsVisible = isCollapsed
        panel.horizontalSwipeEnabled = !isCollapsed

        if needsInitialPosition || requestedScreen != nil {
            position(panel, on: screen, animated: false)
        }

        panel.orderFrontRegardless()
    }

    func synchronize(
        placement: ShelfPlacement,
        dimensions: ShelfDimensions
    ) {
        let displayed = dimensions.displayed()
        let placementChanged = self.placement != placement
        let dimensionsChanged = expandedBodyDimensions != displayed
        self.placement = placement
        if case let .docked(_, _, _, isCollapsed, _) = placement {
            self.isCollapsed = isCollapsed
        } else {
            isCollapsed = false
        }
        if dimensionsChanged, !isPerformingNativeResize {
            setExpandedBodyDimensions(displayed)
        }
        panel?.tabIsVisible = isCollapsed
        panel?.horizontalSwipeEnabled = !isCollapsed
        if let panel,
           placementChanged || dimensionsChanged,
           !isPerformingNativeMove,
           !isPerformingNativeResize {
            position(panel, on: resolvedScreen(for: placement, panel: panel), animated: true)
        }
        layoutResizeHandle()
    }

    func externalDragStarted(on screen: NSScreen?) {
        let wasOpen = panel?.isVisible == true && !isCollapsed
        isTemporarilyExpandedForExternalDrag = !wasOpen
        isPresentedForExternalDrag = true
        didAcceptCurrentExternalDrop = false
        show(on: screen)
    }

    func externalDropAccepted() {
        didAcceptCurrentExternalDrop = true
    }

    func close() {
        pendingPanelResize?.cancel()
        pendingMoveCommit?.cancel()
        panel?.orderOut(nil)
        panel = nil
    }

    var hostingScreen: NSScreen? { panel?.screen }
    var isVisible: Bool { panel?.isVisible == true }

    func toggleCollapsed() {
        guard ShelfDockingAvailability.isEnabled else { return }
        setCollapsed(!isCollapsed)
    }

    func preferencesDidChange() {
        guard let panel,
              let screen = panel.screen ?? ScreenResolver.screenUnderPointer() else { return }
        position(panel, on: screen, animated: true)
    }

    private func setCollapsed(_ collapsed: Bool) {
        guard ShelfDockingAvailability.isEnabled,
              case let .docked(screenID, edge, normalizedMidY, _, order) = placement,
              collapsed != isCollapsed,
              let panel,
              let screen = panel.screen ?? ScreenResolver.screenUnderPointer() else { return }
        pendingPanelResize?.cancel()
        isCollapsed = collapsed
        panel.horizontalSwipeEnabled = !collapsed
        placement = .docked(
            screenID: screenID,
            edge: edge,
            normalizedMidY: normalizedMidY,
            isCollapsed: collapsed,
            order: order
        )
        onPlacementCommitted(placement)

        if collapsed {
            // Let SwiftUI finish sliding the shelf out before reducing the
            // actual window. Resizing both at once makes the glass appear to
            // collapse vertically.
            store.send(.setPanelCollapsed(true))
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
            store.send(.setPanelCollapsed(false))
            panel.tabIsVisible = false
        }
    }

    func layoutDidChange(_ items: [ShelfItem]) {
        // Dropping the last item hides the shelf again. Show Ittan and an
        // in-progress external drag keep this same shelf on screen while empty.
        if lastItemCount > 0, items.isEmpty {
            isHeldVisibleWhileEmpty = false
            isPresentedForExternalDrag = false
        }
        lastItemCount = items.count

        let keepEmptyVisible = items.isEmpty
            && (isPresentedForExternalDrag || isHeldVisibleWhileEmpty)
        guard let panel else {
            if !items.isEmpty || isPresentedForExternalDrag { show() }
            return
        }

        if items.isEmpty, !keepEmptyVisible {
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    func externalDragEnded() {
        let generation = presentationGeneration
        Task { @MainActor in
            // AppKit may report the global drag ending just before the local
            // destination finishes `performDragOperation`, so allow that
            // callback to record a successful Ittan drop first.
            try? await Task.sleep(for: .milliseconds(180))
            guard generation == presentationGeneration else { return }

            if isTemporarilyExpandedForExternalDrag,
               !didAcceptCurrentExternalDrop {
                setCollapsed(true)
            }

            isTemporarilyExpandedForExternalDrag = false
            didAcceptCurrentExternalDrop = false

            guard store.items.isEmpty, !isHeldVisibleWhileEmpty else {
                isPresentedForExternalDrag = false
                return
            }
            try? await Task.sleep(for: .milliseconds(170))
            guard generation == presentationGeneration,
                  store.items.isEmpty,
                  !isHeldVisibleWhileEmpty else {
                isPresentedForExternalDrag = false
                return
            }
            isPresentedForExternalDrag = false
            panel?.orderOut(nil)
        }
    }

    private func makePanel() -> ShelfPanel {
        let panel = ShelfPanel(
            contentRect: NSRect(origin: .zero, size: expandedPanelSize),
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
        panel.delegate = self
        panel.onEdgeDragBegan = { [weak self] in self?.beginEdgeDrag() }
        panel.onEdgeDragChanged = { [weak self] cursor in self?.updateEdgeDrag(cursor: cursor) }
        panel.onEdgeDragEnded = { [weak self] in self?.finishEdgeDrag() }
        // Docking/collapse gestures are temporarily disabled together.
        // panel.onHorizontalSwipe = { ... }
        // panel.onTabClick = { ... }

        let hostingView = ShelfHostingView(
            rootView: ShelfView(
                store: store,
                onToggleCollapsed: { [weak self] in self?.toggleCollapsed() }
            ),
            store: store,
            onExternalDropAccepted: { [weak self] in self?.externalDropAccepted() }
        )
        hostingView.wantsLayer = true
        hostingView.sizingOptions = []

        let resizeHandle = ShelfResizeHandleView(frame: .zero)
        resizeHandle.onResizeBegan = { [weak self] in self?.beginVerticalResize() }
        resizeHandle.onResizeChanged = { [weak self] cursor in self?.updateVerticalResize(cursor: cursor) }
        resizeHandle.onResizeEnded = { [weak self] in self?.finishVerticalResize() }
        let chrome = ShelfChromeContainer(hostingView: hostingView, resizeHandle: resizeHandle)
        chrome.frame = NSRect(
            origin: .zero,
            size: Self.windowSize(forGlass: expandedPanelSize)
        )
        self.resizeHandle = resizeHandle

        panel.contentView = chrome

        self.panel = panel
        layoutResizeHandle()
        return panel
    }

    private var expandedBodyDimensions: ShelfDimensions {
        ShelfDimensions(width: expandedPanelSize.width, height: expandedPanelSize.height)
    }

    private func setExpandedBodyDimensions(_ dimensions: ShelfDimensions) {
        expandedPanelSize = NSSize(
            width: dimensions.width,
            height: dimensions.height
        )
    }

    private func position(_ panel: NSPanel, on screen: NSScreen?, animated: Bool = false) {
        guard let screen else { return }
        let screenFrame = screen.frame
        let preferredSize = isCollapsed
            ? collapsedPanelSize
            : Self.windowSize(forGlass: expandedPanelSize)
        let origin: NSPoint
        var targetSize = preferredSize
        switch placement {
        case .floating:
            let fitted = ShelfAppearance.frame(
                edge: IttanPreferences.shelfEdge,
                dimensions: ShelfDimensions(width: preferredSize.width, height: preferredSize.height),
                screenFrame: screenFrame,
                visibleFrame: screen.visibleFrame,
                normalizedMidY: placement.verticalAnchor
            )
            origin = fitted.origin
            targetSize = fitted.size

        case let .docked(_, edge, normalizedMidY, _, _):
            let midpoint = screenFrame.minY + normalizedMidY * screenFrame.height
            origin = NSPoint(
                x: edge == .left
                    ? screenFrame.minX + edgeMargin
                    : screenFrame.maxX - targetSize.width - edgeMargin,
                y: min(
                    max(midpoint - targetSize.height / 2, screenFrame.minY),
                    screenFrame.maxY - targetSize.height
                )
            )
        }
        let targetFrame = NSRect(origin: origin, size: targetSize)
        guard ShelfWindowMoveCommitGate.shouldApplyFrame(
            currentFrame: panel.frame,
            targetFrame: targetFrame,
            isMoving: isPerformingNativeMove,
            isResizing: isPerformingNativeResize
        ) else { return }
        isApplyingFrame = true
        if animated {
            NSAnimationContext.runAnimationGroup(
                { context in
                    context.duration = 0.26
                    context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    context.allowsImplicitAnimation = true
                    panel.animator().setFrame(targetFrame, display: true)
                },
                completionHandler: { [weak self] in
                    Task { @MainActor in
                        self?.isApplyingFrame = false
                    }
                }
            )
        } else {
            panel.setFrame(targetFrame, display: true, animate: false)
            isApplyingFrame = false
        }
        layoutResizeHandle()
    }

    func windowWillMove(_ notification: Notification) {
        guard !isCollapsed, let panel else { return }
        panel.orderFrontRegardless()
        isPerformingNativeMove = true
        let currentFrame = panel.frame
        panel.setFrame(currentFrame, display: true, animate: false)
        isApplyingFrame = false
    }

    func windowDidMove(_ notification: Notification) {
        guard !isApplyingFrame,
              !isCollapsed,
              !isPerformingNativeResize,
              !isEdgeDragging,
              let panel else { return }
        if !ShelfWindowMoveCommitGate.canCommit(
            pressedMouseButtons: NSEvent.pressedMouseButtons
        ) {
            isPerformingNativeMove = true
        }
        pendingMoveCommit?.cancel()
        pendingMoveCommit = Task { @MainActor [weak self, weak panel] in
            while !ShelfWindowMoveCommitGate.canCommit(
                pressedMouseButtons: NSEvent.pressedMouseButtons
            ) {
                do {
                    try await Task.sleep(for: .milliseconds(8))
                } catch {
                    return
                }
            }
            // AppKit can deliver one final windowDidMove after mouse-up. Give
            // that event time to cancel this task so only the settled frame is
            // persisted and synchronized back to the window.
            do {
                try await Task.sleep(for: .milliseconds(32))
            } catch {
                return
            }
            guard !Task.isCancelled,
                  ShelfWindowMoveCommitGate.canCommit(
                      pressedMouseButtons: NSEvent.pressedMouseButtons,
                      hasSettled: true
                  ),
                  let self,
                  let panel,
                  let screen = panel.screen else { return }
            self.isPerformingNativeMove = false
            self.commitPlacement(for: panel.frame, on: screen)
        }
    }

    private func commitPlacement(for frame: CGRect, on screen: NSScreen) {
        let screenFrame = screen.frame
        let screenID = ScreenResolver.identifier(for: screen)
        if ShelfDockingAvailability.isEnabled,
           let edge = ShelfPlacementGeometry.dockCandidate(
            for: frame,
            screenFrame: screenFrame,
            threshold: 28
        ) {
            placement = .docked(
                screenID: screenID,
                edge: edge,
                normalizedMidY: (frame.midY - screenFrame.minY) / screenFrame.height,
                isCollapsed: false,
                order: 0
            )
        } else {
            placement = ShelfAppearance.placement(
                edge: IttanPreferences.shelfEdge,
                dimensions: expandedBodyDimensions,
                screenID: screenID,
                screenFrame: screenFrame,
                normalizedMidY: screenFrame.height > 0
                    ? (frame.midY - screenFrame.minY) / screenFrame.height
                    : nil
            )
        }
        onPlacementCommitted(placement)
    }

    private func beginVerticalResize() {
        guard !isCollapsed,
              !isPerformingNativeMove,
              !isPerformingNativeResize,
              let panel,
              let screen = panel.screen ?? ScreenResolver.screenUnderPointer() else { return }
        pendingMoveCommit?.cancel()
        panel.orderFrontRegardless()
        isApplyingFrame = false
        isPerformingNativeResize = true
        initialResizeHeight = ShelfResizeHandleLayout.glassHeight(windowHeight: panel.frame.height)
        initialResizeCursor = NSEvent.mouseLocation
        resizeScreenFrame = screen.frame
        resizeVisibleFrame = screen.visibleFrame
        resizeNormalizedMidY = screen.frame.height > 0
            ? (panel.frame.midY - screen.frame.minY) / screen.frame.height
            : nil
    }

    private func updateVerticalResize(cursor: CGPoint) {
        guard isPerformingNativeResize,
              let panel,
              let initialResizeHeight,
              let initialResizeCursor,
              let resizeScreenFrame else { return }
        let height = ShelfHeightResize.height(
            initialHeight: initialResizeHeight,
            cursorDeltaY: cursor.y - initialResizeCursor.y,
            minimumHeight: ShelfDimensions.minimum.height,
            screenHeight: Self.maximumGlassHeight(
                screenFrame: resizeScreenFrame,
                visibleFrame: resizeVisibleFrame
            )
        )
        let frame = ShelfAppearance.frame(
            edge: IttanPreferences.shelfEdge,
            dimensions: ShelfDimensions(
                width: expandedPanelSize.width + ShelfResizeHandleLayout.gutter,
                height: height + ShelfResizeHandleLayout.gutter
            ),
            screenFrame: resizeScreenFrame,
            visibleFrame: resizeVisibleFrame,
            normalizedMidY: resizeNormalizedMidY
        )
        panel.setFrame(frame, display: true, animate: false)
        layoutResizeHandle()
    }

    private func finishVerticalResize() {
        guard isPerformingNativeResize else { return }
        let committedPlacement: ShelfPlacement
        let committedDimensions: ShelfDimensions
        if let panel,
           let screen = panel.screen ?? ScreenResolver.screenUnderPointer() {
            let liveGlassHeight = ShelfResizeHandleLayout.glassHeight(
                windowHeight: panel.frame.height
            )
            let height = ShelfHeightResize.committedHeight(
                liveHeight: liveGlassHeight,
                preferredHeight: expandedPanelSize.height,
                dragStartHeight: initialResizeHeight ?? liveGlassHeight,
                minimumHeight: ShelfDimensions.minimum.height,
                screenHeight: Self.maximumGlassHeight(
                    screenFrame: screen.frame,
                    visibleFrame: screen.visibleFrame
                ),
                rowStep: ShelfLayoutMetrics.cardSize.height + ShelfLayoutMetrics.cardSpacing
            )
            committedDimensions = ShelfDimensions(
                width: ShelfLayoutMetrics.panelWidth,
                height: height
            )
            setExpandedBodyDimensions(committedDimensions)
            committedPlacement = ShelfAppearance.placement(
                edge: IttanPreferences.shelfEdge,
                dimensions: committedDimensions,
                screenID: ScreenResolver.identifier(for: screen),
                screenFrame: screen.frame,
                normalizedMidY: screen.frame.height > 0
                    ? (panel.frame.midY - screen.frame.minY) / screen.frame.height
                    : resizeNormalizedMidY
            )
            placement = committedPlacement
            isPerformingNativeResize = false
            position(panel, on: screen, animated: true)
        } else {
            committedDimensions = expandedBodyDimensions
            committedPlacement = placement
            isPerformingNativeResize = false
        }
        initialResizeHeight = nil
        initialResizeCursor = nil
        resizeScreenFrame = nil
        resizeVisibleFrame = nil
        resizeNormalizedMidY = nil
        onResizeCommitted(committedDimensions, committedPlacement)
    }

    private static func windowSize(forGlass size: NSSize) -> NSSize {
        let window = ShelfResizeHandleLayout.windowSize(
            forGlass: CGSize(width: size.width, height: size.height)
        )
        return NSSize(width: window.width, height: window.height)
    }

    private static func maximumGlassHeight(screenFrame: CGRect, visibleFrame: CGRect?) -> CGFloat {
        max(
            0,
            ShelfAppearance.maximumHeight(screenFrame: screenFrame, visibleFrame: visibleFrame)
                - ShelfResizeHandleLayout.gutter
        )
    }

    private func layoutResizeHandle() {
        guard let chrome = panel?.contentView as? ShelfChromeContainer else { return }
        chrome.edge = IttanPreferences.shelfEdge
        chrome.showsGutter = !isCollapsed
        chrome.needsLayout = true
        chrome.layoutSubtreeIfNeeded()
    }

    private func beginEdgeDrag() {
        guard !isCollapsed,
              !isPerformingNativeResize,
              !isEdgeDragging,
              let panel else { return }
        pendingMoveCommit?.cancel()
        panel.orderFrontRegardless()
        isEdgeDragging = true
        isPerformingNativeMove = true
        centerGuide.hide()
        edgeDragStartCursorY = NSEvent.mouseLocation.y
        edgeDragStartMidY = panel.frame.midY
    }

    private func updateEdgeDrag(cursor: CGPoint) {
        guard isEdgeDragging,
              let panel,
              let screen = ScreenResolver.screenUnderPointer() ?? panel.screen,
              screen.frame.height > 0 else { return }
        let proposedMidY = edgeDragStartMidY + (cursor.y - edgeDragStartCursorY)
        let dimensions = ShelfDimensions(width: panel.frame.width, height: panel.frame.height)
        let centered = ShelfAppearance.frame(
            edge: IttanPreferences.shelfEdge,
            dimensions: dimensions,
            screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame,
            normalizedMidY: 0.5
        )
        let snap = ShelfCenterSnap.decide(
            proposedMidY: proposedMidY,
            centerMidY: centered.midY
        )
        let frame = snap.isSnapped
            ? centered
            : ShelfAppearance.frame(
                edge: IttanPreferences.shelfEdge,
                dimensions: dimensions,
                screenFrame: screen.frame,
                visibleFrame: screen.visibleFrame,
                normalizedMidY: (proposedMidY - screen.frame.minY) / screen.frame.height
            )
        isApplyingFrame = true
        panel.setFrame(frame, display: true, animate: false)
        isApplyingFrame = false
        layoutResizeHandle()
        if snap.isSnapped {
            let wasHidden = !centerGuide.isVisible
            centerGuide.show(on: screen, midY: frame.midY)
            if wasHidden {
                panel.orderFrontRegardless()
            }
        } else {
            centerGuide.hide()
        }
    }

    private func finishEdgeDrag() {
        centerGuide.hide()
        guard isEdgeDragging else { return }
        isEdgeDragging = false
        isPerformingNativeMove = false
        guard let panel,
              let screen = panel.screen ?? ScreenResolver.screenUnderPointer(),
              screen.frame.height > 0 else { return }
        placement = ShelfAppearance.placement(
            edge: IttanPreferences.shelfEdge,
            dimensions: expandedBodyDimensions,
            screenID: ScreenResolver.identifier(for: screen),
            screenFrame: screen.frame,
            normalizedMidY: (panel.frame.midY - screen.frame.minY) / screen.frame.height
        )
        onPlacementCommitted(placement)
        position(panel, on: screen, animated: false)
    }

    private func resolvedScreen(for placement: ShelfPlacement, panel: NSPanel) -> NSScreen? {
        let screenID: String?
        switch placement {
        case let .floating(id, _), let .docked(id, _, _, _, _):
            screenID = id
        }
        return ScreenResolver.screen(withIdentifier: screenID)
            ?? panel.screen
            ?? ScreenResolver.screenUnderPointer()
    }

    private func clampedOrigin(
        _ origin: CGPoint,
        size: CGSize,
        in screenFrame: CGRect
    ) -> CGPoint {
        CGPoint(
            x: min(max(origin.x, screenFrame.minX), screenFrame.maxX - size.width),
            y: min(max(origin.y, screenFrame.minY), screenFrame.maxY - size.height)
        )
    }

}

@MainActor
private final class ShelfHostingView: NSHostingView<ShelfView> {
    private let store: StoreOf<ShelfFeature>
    private let onExternalDropAccepted: () -> Void
    private weak var autoScrollView: NSScrollView?
    private var autoScrollTimer: Timer?
    private var autoScrollVelocity: CGFloat = 0
    private var lastInternalDragPoint: NSPoint?
    private var lastInternalDragIDs: [ShelfItem.ID] = []
    private var lastDragIsExternal = false
    private var lastAcceptedReorderIndex: Int?
    var dockedEdge: ShelfEdge {
        if case let .docked(_, edge, _, _, _) = store.placement { return edge }
        return .left
    }

    init(
        rootView: ShelfView,
        store: StoreOf<ShelfFeature>,
        onExternalDropAccepted: @escaping () -> Void
    ) {
        self.store = store
        self.onExternalDropAccepted = onExternalDropAccepted
        super.init(rootView: rootView)
        registerForDraggedTypes(PasteboardImporter.acceptedTypes)
    }

    @available(*, unavailable)
    required init(rootView: ShelfView) {
        fatalError("Use init(rootView:store:onExternalDropAccepted:)")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard store.isPanelCollapsed else {
            return super.hitTest(point)
        }

        // AppKit supplies `point` in the superview's coordinate system.
        // Convert it exactly as Screendrop's passthrough hosting view does.
        let local = convert(point, from: superview)
        let tabMinY = bounds.midY - 40
        let tabMaxY = bounds.midY + 40
        let edge: ShelfEdge = if case let .docked(_, edge, _, _, _) = store.placement {
            edge
        } else {
            .left
        }
        let isInsideTabHorizontally = edge == .left
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
        store.send(.clearButtonTapped)
    }


    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if sender.draggingSource is FileDragSourceView {
            lastAcceptedReorderIndex = nil
            store.send(.setDropTargeted(false))
            return .move
        }
        guard PasteboardImporter.canImport(sender.draggingPasteboard) else { return [] }
        store.send(.setDropTargeted(true))
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
        guard let scrollView = descendantScrollView(in: self),
              let documentView = scrollView.documentView else { return }
        let documentPoint = documentView.convert(windowPoint, from: nil)
        let pointFromTopLeading = CGPoint(
            x: documentPoint.x - documentView.bounds.minX,
            y: documentView.isFlipped
                ? documentPoint.y - documentView.bounds.minY
                : documentView.bounds.maxY - documentPoint.y
        )
        let draggedIDSet = Set(draggedIDs)
        let remainingItems = store.items.filter { !draggedIDSet.contains($0.id) }
        let insertionIndex = ShelfGridLayout.reorderDestinationIndex(
            pointFromTopLeading: pointFromTopLeading,
            itemCount: remainingItems.count,
            columnCount: 1,
            contentInset: ShelfLayoutMetrics.contentInset,
            cardSize: ShelfLayoutMetrics.cardSize,
            spacing: ShelfLayoutMetrics.cardSpacing
        )
        guard insertionIndex != lastAcceptedReorderIndex else { return }
        lastAcceptedReorderIndex = insertionIndex
        if insertionIndex < remainingItems.count {
            store.send(.previewReorder(
                draggedIDs,
                relativeTo: remainingItems[insertionIndex].id,
                .before
            ))
        } else {
            store.send(.previewReorder(draggedIDs, relativeTo: nil, .before))
        }
    }

    private func updateExternalDropPreview(at windowPoint: NSPoint) {
        if let target = nearestItemView(to: windowPoint, excluding: []) {
            let placement = dropPlacement(for: windowPoint, relativeTo: target)
            store.send(
                .previewExternalDrop(relativeTo: target.item.id, placement)
            )
        } else {
            store.send(.previewExternalDrop(relativeTo: nil, .before))
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
                lastAcceptedReorderIndex = nil
                updateReorderPreview(at: point, draggedIDs: lastInternalDragIDs)
            }
        }
    }

    private func nearestItemView(
        to windowPoint: NSPoint,
        excluding draggedIDs: Set<ShelfItem.ID>
    ) -> FileDragSourceView? {
        descendantItemViews(in: self)
            .filter { !draggedIDs.contains($0.item.id) }
            .min { lhs, rhs in
                squaredDistance(from: windowPoint, to: lhs)
                    < squaredDistance(from: windowPoint, to: rhs)
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

    private func dropPlacement(
        for windowPoint: NSPoint,
        relativeTo target: FileDragSourceView
    ) -> ShelfItemDropPlacement {
        let point = target.convert(windowPoint, from: nil)
        return point.x < target.bounds.midX ? .before : .after
    }

    private func squaredDistance(from windowPoint: NSPoint, to view: NSView) -> CGFloat {
        let point = view.convert(windowPoint, from: nil)
        let deltaX = point.x - view.bounds.midX
        let deltaY = point.y - view.bounds.midY
        return deltaX * deltaX + deltaY * deltaY
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        stopAutoScroll()
        lastAcceptedReorderIndex = nil
        store.send(.setDropTargeted(false))
        if sender?.draggingSource is FileDragSourceView {
            store.send(.cancelReorder)
        } else {
            store.send(.cancelExternalDropPreview)
        }
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        stopAutoScroll()
        lastAcceptedReorderIndex = nil
        store.send(.setDropTargeted(false))
        store.send(.cancelExternalDropPreview)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        stopAutoScroll()
        lastAcceptedReorderIndex = nil
        store.send(.setDropTargeted(false))
        if sender.draggingSource is FileDragSourceView {
            store.send(.commitReorder)
            return true
        }
        let insertionIndex = store.externalDropInsertionIndex
            ?? store.items.endIndex
        store.send(.cancelExternalDropPreview)
        let imported = PasteboardImporter.importItems(from: sender.draggingPasteboard) { urls in
            self.store.send(.addURLsAt(urls, insertionIndex))
        }
        if imported {
            onExternalDropAccepted()
        }
        return imported
    }

}

private final class ShelfChromeContainer: NSView {
    let hostingView: NSView
    let resizeHandle: ShelfResizeHandleView
    var edge: ShelfEdge = .right {
        didSet { needsLayout = true }
    }
    var showsGutter = true {
        didSet { needsLayout = true }
    }

    init(hostingView: NSView, resizeHandle: ShelfResizeHandleView) {
        self.hostingView = hostingView
        self.resizeHandle = resizeHandle
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        addSubview(hostingView)
        addSubview(resizeHandle)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("ShelfChromeContainer is created in code")
    }

    override var isFlipped: Bool { false }

    override func layout() {
        super.layout()
        hostingView.frame = ShelfResizeHandleLayout.glassFrame(
            in: bounds,
            edge: edge,
            showsGutter: showsGutter
        )
        resizeHandle.edge = edge
        resizeHandle.isHidden = !showsGutter
        resizeHandle.frame = ShelfResizeHandleLayout.frame(in: bounds, edge: edge)
        window?.invalidateCursorRects(for: resizeHandle)
    }
}

private final class ShelfPanel: NSPanel {
    var onTabClick: (() -> Void)?
    var onHorizontalSwipe: ((CGFloat) -> Void)?
    var onEdgeDragBegan: (() -> Void)?
    var onEdgeDragChanged: ((CGPoint) -> Void)?
    var onEdgeDragEnded: (() -> Void)?
    var tabIsVisible = false
    var horizontalSwipeEnabled = true
    private var horizontalScroll: CGFloat = 0
    private var didTriggerSwipe = false
    private var isTrackingEdgeDrag = false

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, let contentView {
            let point = contentView.convert(event.locationInWindow, from: nil)
            let itemFrames = descendantItemViews(in: contentView).map {
                $0.convert($0.bounds, to: contentView)
            }
            let handleFrames = descendantResizeHandles(in: contentView).map {
                $0.convert($0.bounds, to: contentView)
            }
            let cornerFrames = descendantCornerHits(in: contentView).map {
                $0.convert($0.bounds, to: contentView)
            }
            let gutterFrames = (contentView as? ShelfChromeContainer).map { chrome in
                chrome.showsGutter
                    ? ShelfResizeHandleLayout.gutterFrames(in: contentView.bounds, edge: chrome.edge)
                    : []
            } ?? []
            let shouldMoveShelf = ShelfWindowDragHitPolicy.shouldMoveShelf(
                from: point,
                interactiveFrames: itemFrames + handleFrames + cornerFrames + gutterFrames
            )
            isTrackingEdgeDrag = shouldMoveShelf
            if shouldMoveShelf {
                onEdgeDragBegan?()
            }
        }

        if event.type == .leftMouseDragged, isTrackingEdgeDrag {
            onEdgeDragChanged?(NSEvent.mouseLocation)
            return
        }

        if event.type == .leftMouseUp, isTrackingEdgeDrag {
            isTrackingEdgeDrag = false
            onEdgeDragEnded?()
        }

        if tabIsVisible, event.type == .leftMouseDown {
            let point = contentView?.convert(event.locationInWindow, from: nil) ?? .zero
            let tabMinY = (contentView?.bounds.midY ?? 0) - 40
            let tabMaxY = (contentView?.bounds.midY ?? 0) + 40
            let contentBounds = contentView?.bounds ?? .zero
            let isInsideTabHorizontally = if let hostingView = contentView as? ShelfHostingView {
                hostingView.dockedEdge == .left
                    ? point.x <= 78
                    : point.x >= contentBounds.maxX - 78
            } else {
                point.x <= 78
            }
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

    private func descendantCornerHits(in view: NSView) -> [ShelfCornerHitView] {
        view.subviews.flatMap { subview in
            let current = (subview as? ShelfCornerHitView).map { [$0] } ?? []
            return current + descendantCornerHits(in: subview)
        }
    }

    private func descendantResizeHandles(in view: NSView) -> [ShelfResizeHandleView] {
        view.subviews.flatMap { subview in
            let current = (subview as? ShelfResizeHandleView).map { [$0] } ?? []
            return current + descendantResizeHandles(in: subview)
        }
    }

    private func descendantItemViews(in view: NSView) -> [FileDragSourceView] {
        view.subviews.flatMap { subview in
            let current = (subview as? FileDragSourceView).map { [$0] } ?? []
            return current + descendantItemViews(in: subview)
        }
    }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}
