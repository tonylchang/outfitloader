import Foundation
import SwiftData

@Model
final class OutfitSlot {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var look: OutfitLook?
    var wardrobeItem: WardrobeItem?
    var categoryKindRawValue: String
    var zIndex: Int
    /// Placement is stored in normalized avatar-canvas coordinates (0.0...1.0)
    /// so saved looks re-render identically across screen sizes.
    var anchorX: Double
    var anchorY: Double
    var scale: Double
    var rotationDegrees: Double
    var opacity: Double

    var categoryKind: CategoryKind? {
        CategoryKind(rawValue: categoryKindRawValue)
    }

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        kind: CategoryKind,
        zIndex: Int,
        anchorX: Double,
        anchorY: Double,
        scale: Double,
        rotationDegrees: Double,
        opacity: Double
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.categoryKindRawValue = kind.rawValue
        self.zIndex = zIndex
        self.anchorX = anchorX
        self.anchorY = anchorY
        self.scale = scale
        self.rotationDegrees = rotationDegrees
        self.opacity = opacity
    }
}
