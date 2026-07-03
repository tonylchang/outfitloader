import CryptoKit
import Foundation
import SwiftUI
import UIKit

/// Metadata for an image file that has been written to disk but not yet
/// inserted into SwiftData. Files are always written before rows exist.
struct ImageAssetDraft {
    let id: UUID
    let kind: ImageAssetKind
    let relativePath: String
    let contentType: String
    let pixelWidth: Int
    let pixelHeight: Int
    let byteCount: Int64
    let source: ImageSource
    let sha256: String
    let isRegenerable: Bool
}

extension ImageAsset {
    convenience init(draft: ImageAssetDraft) {
        self.init(
            id: draft.id,
            kind: draft.kind,
            relativePath: draft.relativePath,
            contentType: draft.contentType,
            pixelWidth: draft.pixelWidth,
            pixelHeight: draft.pixelHeight,
            byteCount: draft.byteCount,
            source: draft.source,
            sha256: draft.sha256,
            isRegenerable: draft.isRegenerable
        )
    }
}

enum MediaStoreError: LocalizedError {
    case containerUnavailable
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .containerUnavailable:
            return "The app's local media directory could not be located."
        case .encodingFailed:
            return "The image could not be encoded for saving."
        }
    }
}

/// Owns all media file IO. SwiftData stores only metadata and relationships;
/// pixels live as files under Application Support (durable, user-created) and
/// Caches (regenerable thumbnails). Filenames never include user-entered names
/// or body-related descriptors.
struct MediaStore {
    private static let thumbnailMaxPixelSize: CGFloat = 600

    // MARK: - Writing

    func writeAvatarOriginal(_ image: UIImage, avatarID: UUID, source: ImageSource) throws -> ImageAssetDraft {
        try writeJPEG(image, relativePath: "Avatars/\(avatarID.uuidString)/original.jpg", kind: .avatarOriginal, source: source)
    }

    func writeAvatarSilhouette(_ image: UIImage, avatarID: UUID) throws -> ImageAssetDraft {
        try writePNG(image, relativePath: "Avatars/\(avatarID.uuidString)/silhouette.png", kind: .avatarSilhouette, source: .generated)
    }

    func writeWardrobeOriginal(_ image: UIImage, itemID: UUID, source: ImageSource) throws -> ImageAssetDraft {
        try writeJPEG(image, relativePath: "Wardrobe/\(itemID.uuidString)/original.jpg", kind: .wardrobeOriginal, source: source)
    }

    func writeWardrobeProcessed(_ image: UIImage, itemID: UUID) throws -> ImageAssetDraft {
        try writePNG(image, relativePath: "Wardrobe/\(itemID.uuidString)/processed.png", kind: .wardrobeProcessed, source: .generated)
    }

    func writeOutfitPreview(_ image: UIImage, lookID: UUID) throws -> ImageAssetDraft {
        try writeJPEG(image, relativePath: "Outfits/\(lookID.uuidString)/preview.jpg", kind: .outfitPreview, source: .generated)
    }

    func writeThumbnail(from image: UIImage) throws -> ImageAssetDraft {
        let assetID = UUID()
        let thumbnail = image.resizedToFit(maxPixelSize: Self.thumbnailMaxPixelSize)
        return try writeJPEG(
            thumbnail,
            relativePath: "Thumbnails/\(assetID.uuidString).jpg",
            kind: .wardrobeThumbnail,
            source: .generated,
            assetID: assetID
        )
    }

    // MARK: - Reading

    func loadImage(for asset: ImageAsset) -> UIImage? {
        loadImage(relativePath: asset.relativePath, kindRawValue: asset.kindRawValue)
    }

    func loadImage(relativePath: String, kindRawValue: String) -> UIImage? {
        guard let kind = ImageAssetKind(rawValue: kindRawValue),
              let url = try? fileURL(relativePath: relativePath, kind: kind)
        else {
            return nil
        }

        return UIImage(contentsOfFile: url.path)
    }

    // MARK: - Deleting

    func deleteMedia(for asset: ImageAsset) {
        guard let kind = asset.kind else {
            return
        }

        deleteFile(relativePath: asset.relativePath, kind: kind)
    }

    func deleteFile(relativePath: String, kind: ImageAssetKind) {
        guard let url = try? fileURL(relativePath: relativePath, kind: kind) else {
            return
        }

        try? FileManager.default.removeItem(at: url)
    }

    func deleteAvatarMedia(avatarID: UUID) {
        deleteMediaDirectory("Avatars/\(avatarID.uuidString)")
    }

    func deleteWardrobeMedia(itemID: UUID) {
        deleteMediaDirectory("Wardrobe/\(itemID.uuidString)")
    }

    func deleteOutfitMedia(lookID: UUID) {
        deleteMediaDirectory("Outfits/\(lookID.uuidString)")
    }

    // MARK: - Encoding

    private func writeJPEG(
        _ image: UIImage,
        relativePath: String,
        kind: ImageAssetKind,
        source: ImageSource,
        assetID: UUID = UUID()
    ) throws -> ImageAssetDraft {
        let normalized = image.normalizedForProcessing()
        guard let data = normalized.jpegData(compressionQuality: 0.9) else {
            throw MediaStoreError.encodingFailed
        }

        return try write(
            data: data,
            image: normalized,
            relativePath: relativePath,
            kind: kind,
            source: source,
            contentType: "image/jpeg",
            assetID: assetID
        )
    }

    private func writePNG(
        _ image: UIImage,
        relativePath: String,
        kind: ImageAssetKind,
        source: ImageSource,
        assetID: UUID = UUID()
    ) throws -> ImageAssetDraft {
        let normalized = image.normalizedForProcessing()
        guard let data = normalized.pngData() else {
            throw MediaStoreError.encodingFailed
        }

        return try write(
            data: data,
            image: normalized,
            relativePath: relativePath,
            kind: kind,
            source: source,
            contentType: "image/png",
            assetID: assetID
        )
    }

    private func write(
        data: Data,
        image: UIImage,
        relativePath: String,
        kind: ImageAssetKind,
        source: ImageSource,
        contentType: String,
        assetID: UUID
    ) throws -> ImageAssetDraft {
        let url = try fileURL(relativePath: relativePath, kind: kind)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: [.atomic, .completeFileProtection])

        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()

        return ImageAssetDraft(
            id: assetID,
            kind: kind,
            relativePath: relativePath,
            contentType: contentType,
            pixelWidth: image.cgImage?.width ?? Int(image.size.width * image.scale),
            pixelHeight: image.cgImage?.height ?? Int(image.size.height * image.scale),
            byteCount: Int64(data.count),
            source: source,
            sha256: digest,
            isRegenerable: kind.isRegenerable
        )
    }

    // MARK: - Locations

    private func fileURL(relativePath: String, kind: ImageAssetKind) throws -> URL {
        try root(for: kind).appending(path: relativePath)
    }

    private func root(for kind: ImageAssetKind) throws -> URL {
        kind.isCacheStored ? try cachesRoot() : try mediaRoot()
    }

    private func mediaRoot() throws -> URL {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw MediaStoreError.containerUnavailable
        }

        return base.appending(path: "Outfitloader/Media", directoryHint: .isDirectory)
    }

    private func cachesRoot() throws -> URL {
        guard let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw MediaStoreError.containerUnavailable
        }

        return base.appending(path: "Outfitloader", directoryHint: .isDirectory)
    }

    private func deleteMediaDirectory(_ relativePath: String) {
        guard let root = try? mediaRoot() else {
            return
        }

        try? FileManager.default.removeItem(at: root.appending(path: relativePath, directoryHint: .isDirectory))
    }
}

extension EnvironmentValues {
    @Entry var mediaStore = MediaStore()
}
