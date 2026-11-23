import AppKit
import ComposableArchitecture

struct NoteClient: Sendable {
    var open: @MainActor @Sendable (URL) -> Void
}

/// Electron treats a present `ELECTRON_RUN_AS_NODE` as "run as Node and exit".
/// Ittan inherits that variable when an Electron tool launches it, and the
/// launched editor inherits it again. The editor exits, and Launch Services
/// opens the note in the default Markdown app.
enum NoteLaunchEnvironment {
    static let blockedKeys = [
        "ELECTRON_RUN_AS_NODE",
        "ELECTRON_NO_ASAR",
        "ELECTRON_NO_ATTACH_CONSOLE",
    ]

    static func make(
        from environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String: String] {
        var copy = environment
        for key in blockedKeys {
            copy.removeValue(forKey: key)
        }
        return copy
    }
}

extension NoteClient: DependencyKey {
    static let liveValue = NoteClient { url in
        guard let editorURL = editorURL(for: url) else { return }
        openFile(at: url, withApplicationAt: editorURL)
    }

    private static func editorURL(for url: URL) -> URL? {
        if let bundleID = IttanPreferences.quickNoteApplicationBundleID {
            guard let editorURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
                NSLog("Ittan: the selected quick note app could not be found (\(bundleID))")
                NSSound.beep()
                return nil
            }
            return editorURL
        }
        guard let editorURL = NSWorkspace.shared.urlForApplication(toOpen: url) else {
            NSLog("Ittan: no application is available to open the quick note")
            NSSound.beep()
            return nil
        }
        return editorURL
    }

    /// `NSWorkspace.open` merges the parent environment back in, so it cannot
    /// clear `ELECTRON_RUN_AS_NODE`. `/usr/bin/open` forwards only its own environment.
    private static func openFile(at fileURL: URL, withApplicationAt applicationURL: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", applicationURL.path, fileURL.path]
        process.environment = NoteLaunchEnvironment.make()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                NSLog("Ittan: failed to open quick note (status \(process.terminationStatus))")
                NSSound.beep()
                return
            }
        } catch {
            NSLog("Ittan: failed to open quick note: \(error.localizedDescription)")
            NSSound.beep()
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
