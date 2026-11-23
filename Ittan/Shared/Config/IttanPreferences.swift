import Foundation

enum ShelfSide: String, Sendable {
    case left
    case right
}

enum ShelfCornerAction: String, CaseIterable, Identifiable, Sendable {
    case none
    case addFiles
    case paste
    case quickNote
    case recentlyRemoved
    case clearShelf
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .none: "None"
        case .addFiles: "Add Files"
        case .paste: "Paste"
        case .quickNote: "Quick Note"
        case .recentlyRemoved: "Recently Removed"
        case .clearShelf: "Clear Shelf"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .none: "minus.circle"
        case .addFiles: "plus"
        case .paste: "doc.on.clipboard"
        case .quickNote: "square.and.pencil"
        case .recentlyRemoved: "clock.arrow.circlepath"
        case .clearShelf: "trash"
        case .settings: "gearshape"
        }
    }
}

enum IttanPreferences {
    static let shelfSideKey = "shelf.side"
    static let expandsForExternalDragKey = "shelf.expandsForExternalDrag"
    static let removesAfterDragKey = "shelf.removesAfterSuccessfulDrag"
    static let historyLimitKey = "history.limit"
    static let shelfEdgeKey = "shelf.appearance.edge"
    static let topLeadingCornerActionKey = "shelf.corner.topLeading"
    static let topTrailingCornerActionKey = "shelf.corner.topTrailing"
    static let bottomLeadingCornerActionKey = "shelf.corner.bottomLeading"
    static let bottomTrailingCornerActionKey = "shelf.corner.bottomTrailing"
    static let cornerActionsMigratedKey = "shelf.corner.migratedToShelfActions"
    static let quickNoteApplicationBundleIDKey = "note.editorBundleID"
    static let defaultTopLeadingCornerAction = ShelfCornerAction.none
    static let defaultTopTrailingCornerAction = ShelfCornerAction.quickNote
    static let defaultBottomLeadingCornerAction = ShelfCornerAction.recentlyRemoved
    static let defaultBottomTrailingCornerAction = ShelfCornerAction.none

    static var quickNoteApplicationBundleID: String? {
        let identifier = UserDefaults.standard.string(forKey: quickNoteApplicationBundleIDKey) ?? ""
        return identifier.isEmpty ? nil : identifier
    }

    /// The previous build stored Clear, Settings, Recently Removed, and Quick Note
    /// on the four corners. Those values were the old defaults, so the first launch
    /// replaces that exact set with the current defaults and leaves any other arrangement.
    static func migrateCornerActions(in defaults: UserDefaults = .standard) {
        let keys = cornerActionKeys
        if !defaults.bool(forKey: cornerActionsMigratedKey) {
            let stored = keys.map { defaults.string(forKey: $0) }
            if stored == ["clearShelf", "settings", "recentlyRemoved", "quickNote"] {
                defaults.set(ShelfCornerAction.none.rawValue, forKey: topLeadingCornerActionKey)
                defaults.set(ShelfCornerAction.quickNote.rawValue, forKey: topTrailingCornerActionKey)
                defaults.set(
                    ShelfCornerAction.recentlyRemoved.rawValue,
                    forKey: bottomLeadingCornerActionKey
                )
                defaults.set(ShelfCornerAction.none.rawValue, forKey: bottomTrailingCornerActionKey)
            }
            defaults.set(true, forKey: cornerActionsMigratedKey)
        }
        for key in keys {
            let raw = defaults.string(forKey: key) ?? ""
            guard !raw.isEmpty, ShelfCornerAction(rawValue: raw) == nil else { continue }
            defaults.set(ShelfCornerAction.none.rawValue, forKey: key)
        }
    }

    private static var cornerActionKeys: [String] {
        [
            topLeadingCornerActionKey,
            topTrailingCornerActionKey,
            bottomLeadingCornerActionKey,
            bottomTrailingCornerActionKey,
        ]
    }

    // Legacy migration only. Remove after every supported pre-workspace build
    // has had an opportunity to create workspace.json.
    static var legacyShelfSide: ShelfSide {
        ShelfSide(rawValue: UserDefaults.standard.string(forKey: shelfSideKey) ?? "") ?? .left
    }

    static var expandsForExternalDrag: Bool {
        value(forKey: expandsForExternalDragKey, default: true)
    }

    static var removesAfterSuccessfulDrag: Bool {
        value(forKey: removesAfterDragKey, default: true)
    }

    static var historyLimit: Int {
        let value = UserDefaults.standard.integer(forKey: historyLimitKey)
        return value > 0 ? value : 50
    }

    static var shelfEdge: ShelfEdge {
        ShelfEdge(rawValue: UserDefaults.standard.string(forKey: shelfEdgeKey) ?? "") ?? .right
    }

    private static func value(forKey key: String, default defaultValue: Bool) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else { return defaultValue }
        return UserDefaults.standard.bool(forKey: key)
    }
}

extension Notification.Name {
    static let ittanPreferencesDidChange = Notification.Name("IttanPreferencesDidChange")
    static let ittanShelfAppearanceDidChange = Notification.Name("IttanShelfAppearanceDidChange")
    static let showIttanSettingsRequested = Notification.Name("ShowIttanSettingsRequested")
}
