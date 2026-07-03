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
    var notes: String?
    var sortIndex: Int
    var isArchived: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        name: String,
        notes: String? = nil,
        sortIndex: Int = 0,
        isArchived: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.name = name
        self.slots = []
        self.notes = notes
        self.sortIndex = sortIndex
        self.isArchived = isArchived
    }
}
