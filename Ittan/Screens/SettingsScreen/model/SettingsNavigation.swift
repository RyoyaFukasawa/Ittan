import Observation

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case behavior
    case about

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "General"
        case .behavior: "Behavior"
        case .about: "About"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .behavior: "rectangle.and.hand.point.up.left"
        case .about: "info.circle"
        }
    }
}

@MainActor
@Observable
final class SettingsNavigation {
    static let shared = SettingsNavigation()
    var selectedTab: SettingsTab? = .general

    private init() {}
}
