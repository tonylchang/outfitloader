import Foundation
import SwiftData

enum CategoryKind: String, CaseIterable, Identifiable {
    case tops
    case bottoms
    case shoes
    case accessories

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tops: return "Tops"
        case .bottoms: return "Bottoms"
        case .shoes: return "Shoes"
        case .accessories: return "Accessories"
        }
    }

    var newItemName: String {
        switch self {
        case .tops: return "Top"
        case .bottoms: return "Bottoms"
        case .shoes: return "Shoes"
        case .accessories: return "Accessory"
        }
    }

    var symbolName: String {
        switch self {
        case .tops: return "tshirt"
        case .bottoms: return "figure.stand"
        case .shoes: return "shoe"
        case .accessories: return "handbag"
        }
    }

    /// Deterministic try-on layering: avatar base, then bottoms, shoes, tops, accessories.
    var layerIndex: Int {
        switch self {
        case .bottoms: return 1
        case .shoes: return 2
        case .tops: return 3
        case .accessories: return 4
        }
    }
}

@Model
final class ClosetCategory {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var kindRawValue: String
    var name: String
    var symbolName: String
    var sortIndex: Int
    var isSystem: Bool
    var isArchived: Bool

    var kind: CategoryKind? {
        CategoryKind(rawValue: kindRawValue)
    }

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        kind: CategoryKind,
        name: String? = nil,
        sortIndex: Int,
        isSystem: Bool = false,
        isArchived: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.kindRawValue = kind.rawValue
        self.name = name ?? kind.displayName
        self.symbolName = kind.symbolName
        self.sortIndex = sortIndex
        self.isSystem = isSystem
        self.isArchived = isArchived
    }
}
