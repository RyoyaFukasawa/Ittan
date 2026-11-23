import Foundation

enum ShelfEdge: String, Codable, Equatable, Sendable {
    case left
    case right
}

enum ShelfPlacement: Codable, Equatable, Sendable {
    case floating(screenID: String?, normalizedFrame: CGRect)
    case docked(
        screenID: String?,
        edge: ShelfEdge,
        normalizedMidY: CGFloat,
        isCollapsed: Bool,
        order: Int
    )

    var screenID: String? {
        switch self {
        case let .floating(screenID, _), let .docked(screenID, _, _, _, _):
            screenID
        }
    }

    /// Vertical center of the shelf, as a fraction of the screen height.
    var verticalAnchor: CGFloat {
        switch self {
        case let .floating(_, frame):
            frame.midY
        case let .docked(_, _, normalizedMidY, _, _):
            normalizedMidY
        }
    }
}

struct ShelfWorkspace: Codable, Equatable, Sendable {
    static let currentVersion = 1

    var version = currentVersion
    var shelves: [Shelf]
    var history: [ShelfItem]
    var activeShelfID: UUID?

    struct Shelf: Identifiable, Codable, Equatable, Sendable {
        let id: UUID
        var name: String?
        var items: [ShelfItem]
        var dimensions: ShelfDimensions = .default
        var placement: ShelfPlacement
    }
}

extension ShelfWorkspace.Shelf {
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case items
        case dimensions
        case placement
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        items = try container.decode([ShelfItem].self, forKey: .items)
        dimensions = try container.decodeIfPresent(
            ShelfDimensions.self,
            forKey: .dimensions
        ) ?? .default
        placement = try container.decode(ShelfPlacement.self, forKey: .placement)
    }
}

struct ShelfDockRequest: Equatable, Sendable {
    let id: UUID
    let preferredMidY: CGFloat
    let height: CGFloat
}

struct ShelfDockResolution: Equatable, Sendable {
    let id: UUID
    let frame: CGRect
}
