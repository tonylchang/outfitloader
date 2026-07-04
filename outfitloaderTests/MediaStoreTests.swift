import CryptoKit
import Testing
import UIKit
@testable import outfitloader

/// Exercises MediaStore file IO in isolated temporary roots so tests never
/// touch the app container.
@MainActor
final class MediaStoreTests {
    private let mediaRoot: URL
    private let cachesRoot: URL
    private let store: MediaStore

    init() throws {
        let base = FileManager.default.temporaryDirectory
            .appending(path: "MediaStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        mediaRoot = base.appending(path: "Media", directoryHint: .isDirectory)
        cachesRoot = base.appending(path: "Caches", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: mediaRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cachesRoot, withIntermediateDirectories: true)
        store = MediaStore(mediaRootOverride: mediaRoot, cachesRootOverride: cachesRoot)
    }

    deinit {
        try? FileManager.default.removeItem(at: mediaRoot.deletingLastPathComponent())
    }

    // MARK: - Writing

    /// Imports store as HEIC where the platform supports encoding it, JPEG elsewhere.
    private var expectedImportExtension: String { MediaStore.isHEICEncodingAvailable ? "heic" : "jpg" }
    private var expectedImportContentType: String { MediaStore.isHEICEncodingAvailable ? "image/heic" : "image/jpeg" }

    @Test func avatarOriginalWriteProducesFileAndAccurateDraft() async throws {
        let image = TestImageFactory.makeImage(size: CGSize(width: 120, height: 240), color: .systemIndigo)
        let avatarID = UUID()

        let draft = try await store.writeAvatarOriginal(image, avatarID: avatarID, source: .camera)

        #expect(draft.relativePath == "Avatars/\(avatarID.uuidString)/original.\(expectedImportExtension)")
        #expect(draft.kind == .avatarOriginal)
        #expect(draft.contentType == expectedImportContentType)
        #expect(draft.source == .camera)
        #expect(draft.isRegenerable == false)
        #expect(draft.pixelWidth == 120)
        #expect(draft.pixelHeight == 240)

        let fileURL = mediaRoot.appending(path: draft.relativePath)
        let data = try Data(contentsOf: fileURL)
        #expect(Int64(data.count) == draft.byteCount)

        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        #expect(digest == draft.sha256)
    }

    @Test func silhouetteWritesPNGIntoAvatarDirectory() async throws {
        let image = TestImageFactory.makeImage(size: CGSize(width: 60, height: 90), color: .systemPurple)
        let avatarID = UUID()

        let draft = try await store.writeAvatarSilhouette(image, avatarID: avatarID)

        #expect(draft.relativePath == "Avatars/\(avatarID.uuidString)/silhouette.png")
        #expect(draft.contentType == "image/png")
        #expect(draft.source == .generated)
        #expect(draft.isRegenerable == true)
        #expect(FileManager.default.fileExists(atPath: mediaRoot.appending(path: draft.relativePath).path))
    }

    @Test func thumbnailIsResizedAndStoredInCaches() async throws {
        let image = TestImageFactory.makeImage(size: CGSize(width: 2000, height: 1000), color: .systemTeal)

        let draft = try await store.writeThumbnail(from: image)

        #expect(draft.kind == .wardrobeThumbnail)
        #expect(draft.isRegenerable == true)
        #expect(max(draft.pixelWidth, draft.pixelHeight) <= 600)
        #expect(draft.pixelWidth > draft.pixelHeight)

        let fileURL = cachesRoot.appending(path: draft.relativePath)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
        #expect(!FileManager.default.fileExists(atPath: mediaRoot.appending(path: draft.relativePath).path))
    }

    @Test func importedOriginalsUseHEICWhenEncodingIsAvailable() async throws {
        let image = TestImageFactory.makeImage(size: CGSize(width: 80, height: 80), color: .systemBrown)

        let draft = try await store.writeWardrobeOriginal(image, itemID: UUID(), source: .photoLibrary)

        #expect(draft.relativePath.hasSuffix(".\(expectedImportExtension)"))
        #expect(draft.contentType == expectedImportContentType)

        // Generated derivatives keep their fixed formats regardless.
        let thumbnail = try await store.writeThumbnail(from: image)
        #expect(thumbnail.contentType == "image/jpeg")
        let preview = try await store.writeOutfitPreview(image, lookID: UUID())
        #expect(preview.contentType == "image/jpeg")
    }

    @Test func replacementWritesUseUniquePaths() async throws {
        let image = TestImageFactory.makeImage(size: CGSize(width: 50, height: 50), color: .systemPink)
        let itemID = UUID()

        let first = try await store.writeWardrobeReplacementOriginal(image, itemID: itemID, source: .photoLibrary)
        let second = try await store.writeWardrobeReplacementOriginal(image, itemID: itemID, source: .photoLibrary)

        #expect(first.relativePath != second.relativePath)
        #expect(FileManager.default.fileExists(atPath: mediaRoot.appending(path: first.relativePath).path))
        #expect(FileManager.default.fileExists(atPath: mediaRoot.appending(path: second.relativePath).path))
    }

    @Test func nonUpOrientationIsNormalizedOnWrite() async throws {
        let source = TestImageFactory.makeImage(size: CGSize(width: 40, height: 80), color: .systemBlue)
        let cgImage = try #require(source.cgImage)
        let rotated = UIImage(cgImage: cgImage, scale: 1, orientation: .right)

        let draft = try await store.writeAvatarOriginal(rotated, avatarID: UUID(), source: .photoLibrary)

        // A .right-oriented 40x80 bitmap displays as 80x40; the stored pixels
        // must match the displayed orientation.
        #expect(draft.pixelWidth == 80)
        #expect(draft.pixelHeight == 40)

        let loaded = try #require(await store.loadImage(relativePath: draft.relativePath, kindRawValue: draft.kind.rawValue))
        #expect(loaded.imageOrientation == .up)
        #expect(loaded.cgImage?.width == 80)
        #expect(loaded.cgImage?.height == 40)
    }

    // MARK: - Reading

    @Test func loadImageRoundTripsWrittenMedia() async throws {
        let image = TestImageFactory.makeImage(size: CGSize(width: 30, height: 45), color: .systemGreen)

        let draft = try await store.writeWardrobeOriginal(image, itemID: UUID(), source: .camera)
        let loaded = try #require(await store.loadImage(relativePath: draft.relativePath, kindRawValue: draft.kind.rawValue))

        #expect(loaded.cgImage?.width == 30)
        #expect(loaded.cgImage?.height == 45)
    }

    @Test func loadImageReturnsNilForUnknownKindOrMissingFile() async throws {
        #expect(await store.loadImage(relativePath: "Wardrobe/nope/original.jpg", kindRawValue: "wardrobeOriginal") == nil)
        #expect(await store.loadImage(relativePath: "anything.jpg", kindRawValue: "notAKind") == nil)
    }

    // MARK: - Deleting

    @Test func deleteFileRemovesWrittenMedia() async throws {
        let image = TestImageFactory.makeImage(size: CGSize(width: 20, height: 20), color: .systemOrange)
        let draft = try await store.writeWardrobeOriginal(image, itemID: UUID(), source: .camera)

        await store.deleteFile(relativePath: draft.relativePath, kind: draft.kind)

        #expect(await store.loadImage(relativePath: draft.relativePath, kindRawValue: draft.kind.rawValue) == nil)
    }

    @Test func deleteWardrobeMediaRemovesTheItemDirectory() async throws {
        let image = TestImageFactory.makeImage(size: CGSize(width: 20, height: 20), color: .systemRed)
        let itemID = UUID()
        let original = try await store.writeWardrobeOriginal(image, itemID: itemID, source: .camera)
        let processed = try await store.writeWardrobeProcessed(image, itemID: itemID)

        await store.deleteWardrobeMedia(itemID: itemID)

        #expect(await store.loadImage(relativePath: original.relativePath, kindRawValue: original.kind.rawValue) == nil)
        #expect(await store.loadImage(relativePath: processed.relativePath, kindRawValue: processed.kind.rawValue) == nil)
        #expect(!FileManager.default.fileExists(atPath: mediaRoot.appending(path: "Wardrobe/\(itemID.uuidString)").path))
    }

    @Test func deleteAllMediaClearsDurableAndCacheRoots() async throws {
        let image = TestImageFactory.makeImage(size: CGSize(width: 20, height: 20), color: .systemYellow)
        _ = try await store.writeAvatarOriginal(image, avatarID: UUID(), source: .camera)
        _ = try await store.writeThumbnail(from: image)

        await store.deleteAllMedia()

        #expect(!FileManager.default.fileExists(atPath: mediaRoot.path))
        #expect(!FileManager.default.fileExists(atPath: cachesRoot.path))
    }
}
