import AppKit

@MainActor
final class ApplicationController {
    static let shared = ApplicationController()

    private var dragMonitor: DragMonitor?

    private init() {}

    func start() {
        let shelf = ShelfController.shared
        shelf.onItemsChanged = { items in
            ShelfPanelController.shared.itemsDidChange(items)
            UndoToastPanelController.shared.reposition()
        }
        shelf.onUndoNoticeChanged = { notice in
            UndoToastPanelController.shared.update(notice: notice)
        }

        dragMonitor = DragMonitor(
            onDragStarted: {
                ShelfPanelController.shared.externalDragStarted(
                    on: ScreenResolver.screenUnderPointer()
                )
            },
            onDragEnded: {
                ShelfPanelController.shared.externalDragEnded()
            }
        )
        dragMonitor?.start()

        if !shelf.items.isEmpty {
            ShelfPanelController.shared.show()
        }
    }

    func stop() {
        dragMonitor?.stop()
        dragMonitor = nil
    }

    func setInternalDragActive(_ active: Bool) {
        dragMonitor?.isInternalDragActive = active
    }
}
