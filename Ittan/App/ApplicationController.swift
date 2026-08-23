import AppKit
import ComposableArchitecture

@MainActor
final class ApplicationController: NSObject {
    static let shared = ApplicationController()

    private var dragMonitor: DragMonitor?

    private override init() {
        super.init()
    }

    func start() {
        observe { [weak self] in
            guard self != nil else { return }
            let items = IttanStore.shelf.items
            let undoNotice = IttanStore.shelf.undoNotice
            ShelfPanelController.shared.layoutDidChange(
                items,
                hasUndoNotice: undoNotice != nil
            )
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

        if !IttanStore.shelf.items.isEmpty {
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
