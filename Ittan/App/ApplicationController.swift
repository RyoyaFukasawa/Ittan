import AppKit
import ComposableArchitecture

@MainActor
final class ApplicationController: NSObject {
    static let shared = ApplicationController()

    private var dragMonitor: DragMonitor?
    private var preferencesObserver: NSObjectProtocol?

    private override init() {
        super.init()
    }

    func start() {
        preferencesObserver = NotificationCenter.default.addObserver(
            forName: .ittanPreferencesDidChange,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                ShelfPanelController.shared.preferencesDidChange()
                IttanStore.shelf.send(.historyLimitChanged(IttanPreferences.historyLimit))
            }
        }

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
                guard IttanPreferences.expandsForExternalDrag else { return }
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
        if let preferencesObserver {
            NotificationCenter.default.removeObserver(preferencesObserver)
            self.preferencesObserver = nil
        }
    }

    func setInternalDragActive(_ active: Bool) {
        dragMonitor?.isInternalDragActive = active
    }
}
