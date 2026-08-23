import AppKit

enum NoteEditorPreference {
    private static let applicationPathKey = "noteEditor.applicationPath"

    static let textEditURL = URL(
        fileURLWithPath: "/System/Applications/TextEdit.app",
        isDirectory: true
    )

    static var applicationURL: URL {
        if let path = UserDefaults.standard.string(forKey: applicationPathKey) {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return textEditURL
    }

    static func select(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: applicationPathKey)
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: applicationPathKey)
    }
}
