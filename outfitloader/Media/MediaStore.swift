import CryptoKit
import Foundation
import ImageIO
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Metadata for an image file that has been written to disk but not yet
/// inserted into SwiftData. Files are always written before rows exist.
struct ImageAssetDraft: Sendable {
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
///
/// Actor isolation serializes IO and keeps image encoding off the main thread.
/// Production code shares one instance so all file access is serialized;
/// SwiftData models never cross into the actor - callers pass value types.
actor MediaStore {
    static let shared = MediaStore()

    /// Whether this platform can encode HEIC. Imported originals prefer HEIC
    /// for its smaller footprint and fall back to JPEG when it is unavailable.
    /// The simulator advertises HEIC support but its HEVC encoder can hang in
    /// CGImageDestinationFinalize, so it is force-disabled there.
    static let isHEICEncodingAvailable: Bool = {
        #if targetEnvironment(simulator)
        return false
        #else
        return (CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []).contains(UTType.heic.identifier)
        #endif
    }()

    private static let thumbnailMaxPixelSize: CGFloat = 600

    /// Overrides for the standard container roots so tests can isolate IO in
    /// temporary directories. Production code uses the defaults.
    private let mediaRootOverride: URL?
    private let cachesRootOverride: URL?

    init(mediaRootOverride: URL? = nil, cachesRootOverride: URL? = nil) {
        self.mediaRootOverride = mediaRootOverride
        self.cachesRootOverride = cachesRootOverride
    }

    // MARK: - Writing

    func writeAvatarOriginal(_ image: UIImage, avatarID: UUID, source: ImageSource) throws -> ImageAssetDraft {
        try writeImport(image, relativeBase: "Avatars/\(avatarID.uuidString)/original", kind: .avatarOriginal, source: source)
    }

    func writeAvatarSilhouette(_ image: UIImage, avatarID: UUID) throws -> ImageAssetDraft {
        try writePNG(image, relativePath: "Avatars/\(avatarID.uuidString)/silhouette.png", kind: .avatarSilhouette, source: .generated)
    }

    func writeWardrobeOriginal(_ image: UIImage, itemID: UUID, source: ImageSource) throws -> ImageAssetDraft {
        try writeImport(image, relativeBase: "Wardrobe/\(itemID.uuidString)/original", kind: .wardrobeOriginal, source: source)
    }

    func writeWardrobeReplacementOriginal(_ image: UIImage, itemID: UUID, source: ImageSource) throws -> ImageAssetDraft {
        let assetID = UUID()
        return try writeImport(
            image,
            relativeBase: "Wardrobe/\(itemID.uuidString)/Originals/\(assetID.uuidString)",
            kind: .wardrobeOriginal,
            source: source,
            assetID: assetID
        )
    }

    func writeWardrobeProcessed(_ image: UIImage, itemID: UUID) throws -> ImageAssetDraft {
        try writePNG(image, relativePath: "Wardrobe/\(itemID.uuidString)/processed.png", kind: .wardrobeProcessed, source: .generated)
    }

    func writeWardrobeReplacementProcessed(_ image: UIImage, itemID: UUID) throws -> ImageAssetDraft {
        let assetID = UUID()
        return try writePNG(
            image,
            relativePath: "Wardrobe/\(itemID.uuidString)/Processed/\(assetID.uuidString).png",
            kind: .wardrobeProcessed,
            source: .generated,
            assetID: assetID
        )
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

    func loadImage(relativePath: String, kindRawValue: String) -> UIImage? {
        guard let kind = ImageAssetKind(rawValue: kindRawValue),
              let url = try? fileURL(relativePath: relativePath, kind: kind)
        else {
            return nil
        }

        return UIImage(contentsOfFile: url.path)
    }

    // MARK: - Integrity

    func fileExists(relativePath: String, kind: ImageAssetKind) -> Bool {
        guard let url = try? fileURL(relativePath: relativePath, kind: kind) else {
            return false
        }

        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Relative paths of every file under both roots, for the debug orphan scan.
    func listAllRelativePaths() -> (durable: Set<String>, cached: Set<String>) {
        (
            durable: relativePaths(under: try? mediaRoot()),
            cached: relativePaths(under: try? cachesRoot())
        )
    }

    private func relativePaths(under root: URL?) -> Set<String> {
        guard let root else {
            return []
        }

        let resolvedRoot = root.resolvingSymlinksInPath().path
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var paths: Set<String> = []
        for case let url as URL in enumerator {
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else {
                continue
            }

            let resolved = url.resolvingSymlinksInPath().path
            if resolved.hasPrefix(resolvedRoot + "/") {
                paths.insert(String(resolved.dropFirst(resolvedRoot.count + 1)))
            }
        }

        return paths
    }

    // MARK: - Deleting

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

    func deleteAllMedia() {
        if let root = try? mediaRoot() {
            try? FileManager.default.removeItem(at: root)
        }

        if let root = try? cachesRoot() {
            try? FileManager.default.removeItem(at: root)
        }
    }

    // MARK: - Encoding

    /// Writes a user-imported original: HEIC when the platform can encode it,
    /// otherwise JPEG. Generated derivatives keep their fixed formats.
    private func writeImport(
        _ image: UIImage,
        relativeBase: String,
        kind: ImageAssetKind,
        source: ImageSource,
        assetID: UUID = UUID()
    ) throws -> ImageAssetDraft {
        let normalized = image.normalizedForProcessing()

        if let heic = heicData(from: normalized, quality: 0.9) {
            return try write(
                data: heic,
                image: normalized,
                relativePath: relativeBase + ".heic",
                kind: kind,
                source: source,
                contentType: "image/heic",
                assetID: assetID
            )
        }

        guard let jpeg = normalized.jpegData(compressionQuality: 0.9) else {
            throw MediaStoreError.encodingFailed
        }

        return try write(
            data: jpeg,
            image: normalized,
            relativePath: relativeBase + ".jpg",
            kind: kind,
            source: source,
            contentType: "image/jpeg",
            assetID: assetID
        )
    }

    private func heicData(from image: UIImage, quality: CGFloat) -> Data? {
        guard Self.isHEICEncodingAvailable, let cgImage = image.cgImage else {
            return nil
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.heic.identifier as CFString, 1, nil) else {
            return nil
        }

        CGImageDestinationAddImage(
            destination,
            cgImage,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return data as Data
    }

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
        if let mediaRootOverride {
            return mediaRootOverride
        }

        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw MediaStoreError.containerUnavailable
        }

        return base.appending(path: "Outfitloader/Media", directoryHint: .isDirectory)
    }

    private func cachesRoot() throws -> URL {
        if let cachesRootOverride {
            return cachesRootOverride
        }

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
    @Entry var mediaStore = MediaStore.shared
}
