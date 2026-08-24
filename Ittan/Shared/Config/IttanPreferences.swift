import Foundation

enum ShelfSide: String, CaseIterable, Identifiable, Sendable {
    case left
    case right

    var id: Self { self }
    var title: String { rawValue.capitalized }
}

enum ShelfCornerAction: String, CaseIterable, Identifiable, Sendable {
    case none
    case addFiles
    case paste
    case selectAll
    case lockAll
    case clearShelf
    case recentlyRemoved
    case quickNote
    case settings
    case collapseShelf

    var id: Self { self }

    var title: String {
        switch self {
        case .none: "None"
        case .addFiles: "Add Files"
        case .paste: "Paste"
        case .selectAll: "Select All"
        case .lockAll: "Lock / Unlock All"
        case .clearShelf: "Clear Shelf"
        case .recentlyRemoved: "Recently Removed"
        case .quickNote: "Quick Note"
        case .settings: "Settings"
        case .collapseShelf: "Collapse Shelf"
        }
    }

    var systemImage: String {
        switch self {
        case .none: "minus.circle"
        case .addFiles: "plus"
        case .paste: "doc.on.clipboard"
        case .selectAll: "checkmark.circle"
        case .lockAll: "lock"
        case .clearShelf: "trash"
        case .recentlyRemoved: "clock.arrow.circlepath"
        case .quickNote: "square.and.pencil"
        case .settings: "gearshape"
        case .collapseShelf: "rectangle.compress.vertical"
        }
    }
}

enum IttanPreferences {
    static let shelfSideKey = "shelf.side"
    static let expandsForExternalDragKey = "shelf.expandsForExternalDrag"
    static let removesAfterDragKey = "shelf.removesAfterSuccessfulDrag"
    static let historyLimitKey = "history.limit"
    static let topLeadingCornerActionKey = "shelf.corner.topLeading"
    static let topTrailingCornerActionKey = "shelf.corner.topTrailing"
    static let bottomLeadingCornerActionKey = "shelf.corner.bottomLeading"
    static let bottomTrailingCornerActionKey = "shelf.corner.bottomTrailing"
    static let defaultTopLeadingCornerAction = ShelfCornerAction.clearShelf
    static let defaultTopTrailingCornerAction = ShelfCornerAction.settings
    static let defaultBottomLeadingCornerAction = ShelfCornerAction.recentlyRemoved
    static let defaultBottomTrailingCornerAction = ShelfCornerAction.quickNote

    static var shelfSide: ShelfSide {
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

    private static func value(forKey key: String, default defaultValue: Bool) -> Bool {
        guard UserDefaults.standard.object(forKey: key) != nil else { return defaultValue }
        return UserDefaults.standard.bool(forKey: key)
    }
}

extension Notification.Name {
    static let ittanPreferencesDidChange = Notification.Name("IttanPreferencesDidChange")
    static let showIttanSettingsRequested = Notification.Name("ShowIttanSettingsRequested")
}
