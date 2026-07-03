import Foundation
import SwiftData

@Model
final class WardrobeItem {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var name: String
    var category: ClosetCategory?
    var categoryKindRawValue: String
    @Relationship(deleteRule: .cascade) var originalImage: ImageAsset?
    @Relationship(deleteRule: .cascade) var processedImage: ImageAsset?
    @Relationship(deleteRule: .cascade) var thumbnailImage: ImageAsset?
    @Relationship(deleteRule: .cascade) var maskImage: ImageAsset?
    var dominantColorName: String?
    var notes: String?
    var sortIndex: Int
    var isArchived: Bool

    var categoryKind: CategoryKind? {
        CategoryKind(rawValue: categoryKindRawValue)
    }

    /// Best image for try-on composition: the transparent cutout when extraction
    /// succeeded, otherwise the original photo.
    var displayImage: ImageAsset? {
        processedImage ?? originalImage
    }

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        name: String,
        kind: CategoryKind,
        dominantColorName: String? = nil,
        notes: String? = nil,
        sortIndex: Int = 0,
        isArchived: Bool = false
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.name = name
        self.categoryKindRawValue = kind.rawValue
        self.dominantColorName = dominantColorName
        self.notes = notes
        self.sortIndex = sortIndex
        self.isArchived = isArchived
    }
}
