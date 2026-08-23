import AppKit
import SwiftUI

@main
struct IttanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Ittan", systemImage: "tray.full") {
            IttanMenuView()
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
    @State private var shelf = ShelfController.shared

    var body: some View {
        Button("Show Ittan") {
            ShelfPanelController.shared.show()
        }

        Button("Clear Shelf") {
            shelf.clear()
        }
        .disabled(shelf.items.isEmpty)

        Divider()

        Text("\(shelf.items.count) item\(shelf.items.count == 1 ? "" : "s")")
            .foregroundStyle(.secondary)

        Divider()

        Button("About Ittan") {
            NSApp.orderFrontStandardAboutPanel(nil)
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("Quit Ittan") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
