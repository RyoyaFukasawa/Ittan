import AppKit
import LinkPresentation
import QuickLookThumbnailing
import Quartz
import SwiftUI
import UniformTypeIdentifiers

struct ShelfView: View {
    @State private var shelf = ShelfController.shared
    @State private var isTabHovered = false
    @State private var isHistoryPresented = false
    private let shelfWidth: CGFloat = 148
    private let expandedLeadingMargin: CGFloat = 14

    var body: some View {
        ZStack(alignment: .leading) {
            shelfContent
                .frame(width: shelfWidth)
                .offset(
                    x: shelf.isPanelCollapsed
                        ? -(shelfWidth + 78)
                        : expandedLeadingMargin
                )

            collapseTab
                .offset(x: shelf.isPanelCollapsed ? 0 : -86)
                .opacity(shelf.isPanelCollapsed ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .animation(.smooth(duration: 0.3, extraBounce: 0), value: shelf.isPanelCollapsed)
    }

    private var shelfContent: some View {
        VStack(spacing: 0) {
                if shelf.items.isEmpty {
                    emptyState
                } else {
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 8) {
                            ForEach(shelf.items) { item in
                                ShelfItemRow(item: item)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 36)
                    }
                    .scrollIndicators(.hidden)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassEffect(
            .regular.interactive(),
            in: RoundedRectangle(cornerRadius: 19, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .strokeBorder(
                    shelf.isDropTargeted ? Color.accentColor : .primary.opacity(0.12),
                    lineWidth: shelf.isDropTargeted ? 2 : 1
                )
        }
        .clipShape(.rect(cornerRadius: 19))
        .shadow(color: .black.opacity(0.2), radius: 14, x: 0, y: 7)
        .overlay(alignment: .topLeading) {
            if !shelf.items.isEmpty {
                Button {
                    shelf.clear()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .glassEffect(.regular.interactive(), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Clear Ittan")
                .padding(8)
                .disabled(!shelf.items.contains(where: { !$0.locked }))
            }
        }
        .overlay(alignment: .bottomLeading) {
            Button {
                isHistoryPresented.toggle()
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .glassEffect(.regular.interactive(), in: Circle())

                    if !shelf.history.isEmpty {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 6, height: 6)
                    }
                }
            }
            .buttonStyle(.plain)
            .help("Recently Removed")
            .padding(8)
            .disabled(shelf.history.isEmpty)
            .popover(isPresented: $isHistoryPresented, arrowEdge: .leading) {
                HistoryView {
                    isHistoryPresented = false
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                guard let url = shelf.createMarkdownNote() else {
                    NSSound.beep()
                    return
                }
                shelf.openMarkdownNote(url)
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .glassEffect(.regular.interactive(), in: Circle())
            }
            .buttonStyle(.plain)
            .help("New Markdown Note")
            .padding(8)
        }
    }

    private var collapseTab: some View {
        Button {
            ShelfPanelController.shared.toggleCollapsed()
        } label: {
            ZStack {
                Capsule(style: .continuous)
                    .fill(Color.accentColor.opacity(0.1))
                    .glassEffect(.regular, in: Capsule(style: .continuous))
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(.primary.opacity(0.18), lineWidth: 1)
                    }
                    .shadow(
                        color: Color.accentColor.opacity(0.12),
                        radius: 4,
                        x: 2,
                        y: 0
                    )

                Capsule(style: .continuous)
                    .fill(.primary.opacity(0.52))
                    .frame(width: 2, height: 24)
            }
            .frame(width: isTabHovered ? 27 : 24, height: 69)
            .frame(width: 78, height: 80, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: 78, height: 80, alignment: .leading)
        // Push the square leading edge one point off-screen so the glass
        // outline does not draw a rectangular seam against the display edge.
        .offset(x: -8)
        .onHover { hovering in
            withAnimation(.smooth(duration: 0.16, extraBounce: 0)) {
                isTabHovered = hovering
            }
        }
        .help("Show Ittan · Right-click for options")
    }

    private var emptyState: some View {
        HStack(spacing: 8) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(shelf.isDropTargeted ? Color.accentColor : Color.secondary)

            Text(shelf.isDropTargeted ? "Let go to add" : "Drop files here")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ShelfItemRow: View {
    let item: ShelfItem
    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            FileDragSource(item: item)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 5) {
                ShelfThumbnail(url: item.url)
                    .frame(width: 64, height: 64)

                Text(item.exists ? item.displayName : "File is unavailable")
                    .font(.system(size: 10.5, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(item.exists ? Color.primary : Color.red)
                    .frame(width: 92)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)

            Button {
                ShelfController.shared.remove(id: item.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .glassEffect(.regular.interactive(), in: Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .opacity(isHovered && !item.locked ? 1 : 0)
            .disabled(item.locked)
            .help("Remove from Ittan")
            .accessibilityLabel("Remove from Ittan")
            .padding(.top, 2)
            .padding(.trailing, 2)

            if item.locked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .glassEffect(.regular.interactive(), in: Circle())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(4)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: 100, height: 94)
        .background {
            RoundedRectangle(cornerRadius: 9)
                .fill(
                    ShelfController.shared.selectedIDs.contains(item.id)
                        ? Color.primary.opacity(0.09)
                        : (isHovered ? Color.primary.opacity(0.055) : Color.clear)
                )
                .overlay {
                    if ShelfController.shared.selectedIDs.contains(item.id) {
                        RoundedRectangle(cornerRadius: 9)
                            .strokeBorder(Color.primary.opacity(0.24), lineWidth: 1)
                    }
                }
        }
        .clipShape(.rect(cornerRadius: 9))
        .onHover { isHovered = $0 }
    }
}

private struct ShelfThumbnail: View {
    let url: URL
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .clipShape(.rect(cornerRadius: 7))
        .task(id: url) {
            image = await ThumbnailLoader.thumbnail(for: url, size: CGSize(width: 84, height: 84))
        }
    }
}

private enum ThumbnailLoader {
    static func thumbnail(for url: URL, size: CGSize) async -> NSImage? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        if url.pathExtension.lowercased() == "webloc" {
            return await LinkPreviewLoader.thumbnail(for: url)
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .thumbnail
        )

        return await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
                continuation.resume(returning: representation?.nsImage)
            }
        }
    }
}

private enum LinkPreviewLoader {
    static func thumbnail(for webLocationFile: URL) async -> NSImage? {
        let cacheURL = webLocationFile.deletingPathExtension().appendingPathExtension("preview.png")
        if let cached = NSImage(contentsOf: cacheURL) {
            return cached
        }

        guard let destination = webURL(from: webLocationFile),
              ["http", "https"].contains(destination.scheme?.lowercased() ?? "") else {
            return nil
        }

        do {
            let metadata = try await LPMetadataProvider().startFetchingMetadata(for: destination)
            guard let provider = metadata.imageProvider ?? metadata.iconProvider,
                  let data = await imageData(from: provider),
                  let image = NSImage(data: data) else {
                return nil
            }
            cache(image, at: cacheURL)
            return image
        } catch {
            NSLog("Ittan: link preview failed for \(destination.absoluteString): \(error.localizedDescription)")
            return nil
        }
    }

    private static func imageData(from provider: NSItemProvider) async -> Data? {
        await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }

    private static func webURL(from file: URL) -> URL? {
        guard let data = try? Data(contentsOf: file),
              let value = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
              ) as? [String: Any],
              let string = value["URL"] as? String else {
            return nil
        }
        return URL(string: string)
    }

    private static func cache(_ image: NSImage, at url: URL) {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url, options: .atomic)
    }
}

private struct FileDragSource: NSViewRepresentable {
    let item: ShelfItem

    func makeNSView(context: Context) -> FileDragSourceView {
        FileDragSourceView(item: item)
    }

    func updateNSView(_ nsView: FileDragSourceView, context: Context) {
        nsView.item = item
    }
}

@MainActor
private final class FileDragSourceView: NSView, NSDraggingSource {
    var item: ShelfItem
    private var mouseDownEvent: NSEvent?
    private var draggedItems: [ShelfItem] = []
    private var shouldCollapseSelectionOnClick = false

    init(item: ShelfItem) {
        self.item = item
        super.init(frame: .zero)
        toolTip = item.path
        registerForDraggedTypes(PasteboardImporter.acceptedTypes)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let controller = ShelfController.shared
        shouldCollapseSelectionOnClick = !event.modifierFlags.contains(.command)
            && !event.modifierFlags.contains(.shift)
            && controller.selectedIDs.contains(item.id)
            && controller.selectedIDs.count > 1
        if !shouldCollapseSelectionOnClick {
            controller.select(id: item.id, modifiers: event.modifierFlags)
        }
        if event.clickCount == 2 {
            ShelfController.shared.open(id: item.id)
            return
        }
        mouseDownEvent = event
    }

    override func mouseUp(with event: NSEvent) {
        mouseDownEvent = nil
        if shouldCollapseSelectionOnClick {
            ShelfController.shared.select(id: item.id, modifiers: [])
        }
        shouldCollapseSelectionOnClick = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let mouseDownEvent, item.exists else { return }
        let start = convert(mouseDownEvent.locationInWindow, from: nil)
        let current = convert(event.locationInWindow, from: nil)
        guard hypot(current.x - start.x, current.y - start.y) > 3 else { return }
        self.mouseDownEvent = nil
        shouldCollapseSelectionOnClick = false

        draggedItems = ShelfController.shared.dragItems(startingWith: item.id)
        let draggingItems = draggedItems.enumerated().map { index, draggedItem in
            let dragItem = NSDraggingItem(pasteboardWriter: ShelfPasteboardWriter.make(for: draggedItem))
            let icon = NSWorkspace.shared.icon(forFile: draggedItem.path)
            icon.size = NSSize(width: 48, height: 48)
            dragItem.setDraggingFrame(
                NSRect(
                    x: current.x - 24 + CGFloat(index * 3),
                    y: current.y - 24 - CGFloat(index * 3),
                    width: 48,
                    height: 48
                ),
                contents: icon
            )
            return dragItem
        }
        beginDraggingSession(with: draggingItems, event: event, source: self)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard !(sender.draggingSource is FileDragSourceView) else { return [] }
        ShelfController.shared.isDropTargeted = true
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        ShelfController.shared.isDropTargeted = false
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        ShelfController.shared.isDropTargeted = false
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        ShelfController.shared.isDropTargeted = false
        guard !(sender.draggingSource is FileDragSourceView) else { return false }
        return PasteboardImporter.importItems(from: sender.draggingPasteboard)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        if !ShelfController.shared.selectedIDs.contains(item.id) {
            ShelfController.shared.select(id: item.id, modifiers: [])
        }
        let menu = NSMenu()
        menu.addItem(item: "Open", action: #selector(openItem))
        addOpenWithMenu(to: menu)
        menu.addItem(item: "Quick Look", action: #selector(quickLookItem))
        menu.addItem(item: "Share…", action: #selector(shareItem))
        menu.addItem(.separator())
        menu.addItem(item: "Reveal in Finder", action: #selector(revealItem))
        menu.addItem(item: "Copy", action: #selector(copyItem))
        menu.addItem(item: "Copy Path", action: #selector(copyPath))
        menu.addItem(item: "Rename…", action: #selector(renameItem))
        menu.addItem(item: item.locked ? "Unlock" : "Lock", action: #selector(toggleLock))
        menu.addItem(item: "Select All", action: #selector(selectAllItems))
        menu.addItem(.separator())
        menu.addItem(item: "Remove from Ittan", action: #selector(removeItem))
        menu.items.last?.isEnabled = !item.locked
        for menuItem in menu.items where menuItem.action != nil {
            menuItem.target = self
        }
        return menu
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        context == .outsideApplication ? .copy : []
    }

    func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
        ApplicationController.shared.setInternalDragActive(true)
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        ApplicationController.shared.setInternalDragActive(false)
        if operation != [] {
            ShelfController.shared.dragOutSucceeded(ids: draggedItems.map(\.id))
        }
        draggedItems = []
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "a" {
            ShelfController.shared.selectAll()
            return
        }
        super.keyDown(with: event)
    }

    @objc private func openItem() { ShelfController.shared.open(id: item.id) }
    @objc private func quickLookItem() { IttanQuickLookController.shared.show(item.url) }
    @objc private func shareItem() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            NSSharingServicePicker(items: [self.item.url]).show(
                relativeTo: self.bounds,
                of: self,
                preferredEdge: .maxX
            )
        }
    }
    @objc private func revealItem() { ShelfController.shared.reveal(id: item.id) }
    @objc private func copyItem() { ShelfController.shared.copyToPasteboard(id: item.id) }
    @objc private func copyPath() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.path, forType: .string)
    }
    @objc private func toggleLock() { ShelfController.shared.toggleLock(id: item.id) }
    @objc private func selectAllItems() { ShelfController.shared.selectAll() }
    @objc private func renameItem() {
        let alert = NSAlert()
        alert.messageText = "Rename Item"
        alert.informativeText = "Enter a new filename."
        let field = NSTextField(string: item.displayName)
        field.frame.size = NSSize(width: 300, height: 24)
        alert.accessoryView = field
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        if !ShelfController.shared.rename(id: item.id, to: field.stringValue) {
            NSSound.beep()
        }
    }
    @objc private func removeItem() { ShelfController.shared.remove(id: item.id) }

    private func addOpenWithMenu(to menu: NSMenu) {
        let applications = NSWorkspace.shared.urlsForApplications(toOpen: item.url)
        guard !applications.isEmpty else { return }
        let submenu = NSMenu()
        for application in applications.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let menuItem = NSMenuItem(
                title: FileManager.default.displayName(atPath: application.path),
                action: #selector(openWithApplication(_:)),
                keyEquivalent: ""
            )
            menuItem.target = self
            menuItem.representedObject = application
            menuItem.image = NSWorkspace.shared.icon(forFile: application.path)
            menuItem.image?.size = NSSize(width: 16, height: 16)
            submenu.addItem(menuItem)
        }
        let parent = NSMenuItem(title: "Open With", action: nil, keyEquivalent: "")
        parent.submenu = submenu
        menu.addItem(parent)
    }

    @objc private func openWithApplication(_ sender: NSMenuItem) {
        guard let application = sender.representedObject as? URL else { return }
        NSWorkspace.shared.open(
            [item.url],
            withApplicationAt: application,
            configuration: NSWorkspace.OpenConfiguration()
        )
    }
}

private final class IttanQuickLookController: NSObject, QLPreviewPanelDataSource {
    static let shared = IttanQuickLookController()
    private var urls: [URL] = []

    func show(_ url: URL) {
        urls = [url]
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { urls.count }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> any QLPreviewItem {
        urls[index] as NSURL
    }
}

private struct HistoryView: View {
    @State private var shelf = ShelfController.shared
    let onBecameEmpty: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Recently Removed")
                        .font(.system(size: 14, weight: .semibold))
                    Text("\(shelf.history.count) items")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Clear") {
                    closeThen { shelf.clearHistory() }
                }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .disabled(shelf.history.isEmpty)
            }
            .padding(14)

            Divider()

            if shelf.history.isEmpty {
                VStack(spacing: 9) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(.tertiary)

                    Text("No Removed Items")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(shelf.history) { item in
                            HStack(spacing: 10) {
                                ShelfThumbnail(url: item.url)
                                    .frame(width: 38, height: 38)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.displayName)
                                        .font(.system(size: 11, weight: .medium))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Text(item.parentName)
                                        .font(.system(size: 9.5))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 6)

                                Button("Restore") {
                                    if shelf.history.count == 1 {
                                        closeThen {
                                            shelf.restoreFromHistory(id: item.id)
                                        }
                                    } else {
                                        shelf.restoreFromHistory(id: item.id)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 54)
                            .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))
                        }
                    }
                    .padding(10)
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(width: 300, height: 390)
        .background(.ultraThinMaterial)
        .onChange(of: shelf.history.isEmpty) { _, isEmpty in
            if isEmpty { onBecameEmpty() }
        }
    }

    private func closeThen(_ action: @escaping @MainActor () -> Void) {
        onBecameEmpty()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            action()
        }
    }
}

private extension NSMenu {
    func addItem(item title: String, action: Selector) {
        addItem(NSMenuItem(title: title, action: action, keyEquivalent: ""))
    }
}
