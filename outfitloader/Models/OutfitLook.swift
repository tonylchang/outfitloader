import Foundation
import SwiftData

@Model
final class OutfitLook {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var name: String
    var avatarProfile: AvatarProfile?
    @Relationship(deleteRule: .cascade, inverse: \OutfitSlot.look)
    var slots: [OutfitSlot]
    @Relationship(deleteRule: .cascade) var previewImage: ImageAsset?
    var avatarScale: Double = 1
    var avatarRotationDegrees: Double = 0
    var avatarOpacity: Double = 1
    var notes: String?
    var isArchived: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        name: String,
        avatarScale: Double = 1,
        avatarRotationDegrees: Double = 0,
        avatarOpacity: Double = 1,
        notes: String? = nil,
        isArchived: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.name = name
        self.slots = []
        self.avatarScale = avatarScale
        self.avatarRotationDegrees = avatarRotationDegrees
        self.avatarOpacity = avatarOpacity
        self.notes = notes
        self.isArchived = isArchived
    }
}
