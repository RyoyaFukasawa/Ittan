import AppKit
import ComposableArchitecture

@MainActor
final class ApplicationController: NSObject {
    static let shared = ApplicationController()

    private var dragMonitor: DragMonitor?
    private var preferencesObserver: NSObjectProtocol?
    private var appearanceObserver: NSObjectProtocol?
    private var settingsRequestObserver: NSObjectProtocol?

    private override init() {
        super.init()
    }

    func start() {
        IttanPreferences.migrateCornerActions()
        IttanStore.workspace.send(.ensureShelf(placement: IttanStore.defaultPlacement))
        preferencesObserver = NotificationCenter.default.addObserver(
            forName: .ittanPreferencesDidChange,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                ShelfWindowCoordinator.shared.preferencesDidChange()
                IttanStore.workspace.send(
                    .historyLimitChanged(IttanPreferences.historyLimit)
                )
            }
        }
        appearanceObserver = NotificationCenter.default.addObserver(
            forName: .ittanShelfAppearanceDidChange,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                ShelfWindowCoordinator.shared.applyAppearancePreferences()
            }
        }
        settingsRequestObserver = NotificationCenter.default.addObserver(
            forName: .showIttanSettingsRequested,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in SettingsWindowController.show() }
        }

        observe { [weak self] in
            guard self != nil else { return }
            _ = IttanStore.workspace.shelves
            _ = IttanStore.workspace.activeShelfID
            ShelfWindowCoordinator.shared.synchronize()
        }

        dragMonitor = DragMonitor(
            onDragStarted: {
                ShelfWindowCoordinator.shared.relocateActiveShelfToPointer()
                if IttanPreferences.expandsForExternalDrag {
                    ShelfWindowCoordinator.shared.externalDragStarted(
                        on: ScreenResolver.screenUnderPointer()
                    )
                }
            },
            onDragMoved: {
                ShelfWindowCoordinator.shared.relocateActiveShelfToPointer()
            },
            onDragEnded: {
                ShelfWindowCoordinator.shared.externalDragEnded()
            }
        )
        dragMonitor?.start()

        ShelfWindowCoordinator.shared.synchronize()
        ShelfWindowCoordinator.shared.applyAppearancePreferences()
    }

    func stop() {
        dragMonitor?.stop()
        dragMonitor = nil
        if let preferencesObserver {
            NotificationCenter.default.removeObserver(preferencesObserver)
            self.preferencesObserver = nil
        }
        if let appearanceObserver {
            NotificationCenter.default.removeObserver(appearanceObserver)
            self.appearanceObserver = nil
        }
        if let settingsRequestObserver {
            NotificationCenter.default.removeObserver(settingsRequestObserver)
            self.settingsRequestObserver = nil
        }
    }

    func setInternalDragActive(_ active: Bool) {
        dragMonitor?.isInternalDragActive = active
    }
}
