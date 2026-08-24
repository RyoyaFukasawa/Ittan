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
    private let store = IttanStore.shelf

    var body: some View {
        Button("Show Ittan") {
            ShelfPanelController.shared.show()
        }

        Button("Clear Shelf") {
            store.send(.clearButtonTapped)
        }
        .disabled(store.items.isEmpty)

        Divider()

        Text("\(store.items.count) item\(store.items.count == 1 ? "" : "s")")
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
}
