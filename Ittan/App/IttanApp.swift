import AppKit
import ComposableArchitecture
import SwiftUI

@main
struct IttanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Ittan", systemImage: "tray.full") {
            IttanMenuView()
        }

        Settings {
            IttanSettingsView()
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

        SettingsLink {
            Text("Settings…")
        }

        Button("Quit Ittan") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

private struct IttanSettingsView: View {
    @State private var editorURL = NoteEditorPreference.applicationURL

    var body: some View {
        Form {
            LabeledContent("Markdown editor") {
                HStack(spacing: 8) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: editorURL.path))
                        .resizable()
                        .frame(width: 24, height: 24)

                    Text(editorURL.deletingPathExtension().lastPathComponent)
                        .lineLimit(1)

                    Button("Choose…", action: chooseEditor)
                }
            }

            HStack {
                Spacer()
                Button("Use TextEdit") {
                    NoteEditorPreference.reset()
                    editorURL = NoteEditorPreference.applicationURL
                }
                .disabled(editorURL.standardizedFileURL == NoteEditorPreference.textEditURL.standardizedFileURL)
            }
        }
        .formStyle(.grouped)
        .padding(8)
        .frame(width: 430, height: 150)
    }

    private func chooseEditor() {
        let panel = NSOpenPanel()
        panel.title = "Choose Markdown Editor"
        panel.prompt = "Choose"
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        NoteEditorPreference.select(url)
        editorURL = url
    }
}
