import Foundation
import SwiftData

enum ImageAssetKind: String, CaseIterable {
    case avatarOriginal
    case avatarSilhouette
    case wardrobeOriginal
    case wardrobeProcessed
    case wardrobeThumbnail
    case outfitPreview

    var isRegenerable: Bool {
        switch self {
        case .avatarOriginal, .wardrobeOriginal:
            return false
        case .avatarSilhouette, .wardrobeProcessed, .wardrobeThumbnail, .outfitPreview:
            return true
        }
    }

    /// Thumbnails live in Caches; everything else is durable media in Application Support.
    var isCacheStored: Bool {
        self == .wardrobeThumbnail
    }
}

enum ImageSource: String {
    case camera
    case photoLibrary
    case generated
}

@Model
final class ImageAsset {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var kindRawValue: String
    var relativePath: String
    var contentType: String
    var pixelWidth: Int
    var pixelHeight: Int
    var byteCount: Int64
    var sourceRawValue: String
    var sha256: String?
    var isRegenerable: Bool

    var kind: ImageAssetKind? {
        ImageAssetKind(rawValue: kindRawValue)
    }

    var source: ImageSource? {
        ImageSource(rawValue: sourceRawValue)
    }

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        updatedAt: Date = .now,
        kind: ImageAssetKind,
        relativePath: String,
        contentType: String,
        pixelWidth: Int,
        pixelHeight: Int,
        byteCount: Int64,
        source: ImageSource,
        sha256: String? = nil,
        isRegenerable: Bool
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.kindRawValue = kind.rawValue
        self.relativePath = relativePath
        self.contentType = contentType
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.byteCount = byteCount
        self.sourceRawValue = source.rawValue
        self.sha256 = sha256
        self.isRegenerable = isRegenerable
    }
}
