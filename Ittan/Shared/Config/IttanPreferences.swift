import Foundation

enum ShelfSide: String, CaseIterable, Identifiable, Sendable {
    case left
    case right

    var id: Self { self }
    var title: String { rawValue.capitalized }
}

enum IttanPreferences {
    static let shelfSideKey = "shelf.side"
    static let expandsForExternalDragKey = "shelf.expandsForExternalDrag"
    static let removesAfterDragKey = "shelf.removesAfterSuccessfulDrag"
    static let historyLimitKey = "history.limit"

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
}
