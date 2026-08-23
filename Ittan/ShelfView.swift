import AppKit
import LinkPresentation
import QuickLookThumbnailing
import SwiftUI
import UniformTypeIdentifiers

struct ShelfView: View {
    @State private var shelf = ShelfController.shared
    @State private var isTabHovered = false
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
                        .padding(.vertical, 8)
                    }
                    .scrollIndicators(.hidden)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassEffect(
            .regular.interactive(),
            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(
                    shelf.isDropTargeted ? Color.accentColor : .primary.opacity(0.12),
                    lineWidth: shelf.isDropTargeted ? 2 : 1
                )
        }
        .clipShape(.rect(cornerRadius: 13))
        .shadow(color: .black.opacity(0.2), radius: 14, x: 0, y: 7)
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
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .opacity(isHovered ? 1 : 0)
            .help("Remove from Ittan")
            .accessibilityLabel("Remove from Ittan")
            .padding(.top, 2)
            .padding(.trailing, 2)
        }
        .frame(width: 100, height: 94)
        .background(isHovered ? Color.primary.opacity(0.055) : Color.clear)
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

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            ShelfController.shared.open(id: item.id)
            return
        }
        mouseDownEvent = event
    }

    override func mouseUp(with event: NSEvent) {
        mouseDownEvent = nil
    }

    override func mouseDragged(with event: NSEvent) {
        guard let mouseDownEvent, item.exists else { return }
        let start = convert(mouseDownEvent.locationInWindow, from: nil)
        let current = convert(event.locationInWindow, from: nil)
        guard hypot(current.x - start.x, current.y - start.y) > 3 else { return }
        self.mouseDownEvent = nil

        let dragItem = NSDraggingItem(pasteboardWriter: ShelfPasteboardWriter.make(for: item))
        let icon = NSWorkspace.shared.icon(forFile: item.path)
        icon.size = NSSize(width: 48, height: 48)
        dragItem.setDraggingFrame(
            NSRect(x: current.x - 24, y: current.y - 24, width: 48, height: 48),
            contents: icon
        )
        beginDraggingSession(with: [dragItem], event: event, source: self)
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
        let menu = NSMenu()
        menu.addItem(item: "Open", action: #selector(openItem))
        menu.addItem(item: "Reveal in Finder", action: #selector(revealItem))
        menu.addItem(item: "Copy", action: #selector(copyItem))
        menu.addItem(.separator())
        menu.addItem(item: "Remove from Ittan", action: #selector(removeItem))
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
            ShelfController.shared.dragOutSucceeded(id: item.id)
        }
    }

    @objc private func openItem() { ShelfController.shared.open(id: item.id) }
    @objc private func revealItem() { ShelfController.shared.reveal(id: item.id) }
    @objc private func copyItem() { ShelfController.shared.copyToPasteboard(id: item.id) }
    @objc private func removeItem() { ShelfController.shared.remove(id: item.id) }
}

private extension NSMenu {
    func addItem(item title: String, action: Selector) {
        addItem(NSMenuItem(title: title, action: action, keyEquivalent: ""))
    }
}
