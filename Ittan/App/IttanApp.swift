import AppKit
import ComposableArchitecture
import SwiftUI

@main
struct IttanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            IttanMenuView()
        } label: {
            Image("MenuBarIcon")
                .renderingMode(.template)
        }

    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        ApplicationController.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        ApplicationController.shared.stop()
    }
}

private struct IttanMenuView: View {
    private let store = IttanStore.workspace

    private var activeItemCount: Int {
        guard let id = store.activeShelfID else { return 0 }
        return store.shelves[id: id]?.items.count ?? 0
    }

    var body: some View {
        Button("Show Ittan") {
            ShelfWindowCoordinator.shared.showActive()
        }

        Button("New Note") {
            createNote()
        }

        Button("Clear Shelf") {
            ShelfWindowCoordinator.shared.clearActive()
        }
        .disabled(activeItemCount == 0)

        Menu("Recently Removed") {
            if store.history.isEmpty {
                Button("None") {}
                    .disabled(true)
            } else {
                ForEach(store.history) { item in
                    Button(item.displayName) {
                        store.send(.restoreFromHistory(
                            id: item.id,
                            defaultPlacement: IttanStore.defaultPlacement
                        ))
                        ShelfWindowCoordinator.shared.showActive()
                    }
                }
                Divider()
                Button("Clear") {
                    store.send(.clearHistory)
                }
            }
        }

        Divider()

        Text("\(activeItemCount) item\(activeItemCount == 1 ? "" : "s")")
            .foregroundStyle(.secondary)

        Divider()

        Button("About Ittan") {
            NSApp.orderFrontStandardAboutPanel(nil)
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("Settings…") {
            SettingsWindowController.show()
        }
        .keyboardShortcut(",")

        Button("Quit Ittan") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private func createNote() {
        let id = store.activeShelfID ?? store.shelves.first?.id
        guard let id else { return }
        store.send(.shelves(.element(id: id, action: .createNoteButtonTapped)))
        ShelfWindowCoordinator.shared.showActive()
    }
}
