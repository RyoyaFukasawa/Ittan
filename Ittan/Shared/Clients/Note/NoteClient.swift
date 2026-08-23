import AppKit
import ComposableArchitecture

struct NoteClient: Sendable {
    var open: @MainActor @Sendable (URL) -> Void
}

extension NoteClient: DependencyKey {
    static let liveValue = NoteClient { url in
        let editorURL = NoteEditorPreference.applicationURL
        guard FileManager.default.fileExists(atPath: editorURL.path) else {
            NSLog("Ittan: note editor is not available at \(editorURL.path)")
            NSSound.beep()
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open(
            [url],
            withApplicationAt: editorURL,
            configuration: configuration
        ) { application, error in
            if let error {
                NSLog("Ittan: failed to open quick note: \(error.localizedDescription)")
                NSSound.beep()
                return
            }
            application?.activate(options: [.activateAllWindows])
        }
    }

    static let testValue = NoteClient { _ in }
}

extension DependencyValues {
    var noteClient: NoteClient {
        get { self[NoteClient.self] }
        set { self[NoteClient.self] = newValue }
    }
}
