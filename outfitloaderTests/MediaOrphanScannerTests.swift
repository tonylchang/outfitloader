import SwiftData
import Testing
import UIKit
@testable import outfitloader

@MainActor
final class MediaOrphanScannerTests {
    private let container: ModelContainer
    private let context: ModelContext
    private let mediaStore: MediaStore
    private let scanner: MediaOrphanScanner
    private let cleanupRoot: URL

    init() throws {
        container = try ModelContainerFactory.makeInMemory()
        context = ModelContext(container)

        cleanupRoot = FileManager.default.temporaryDirectory
            .appending(path: "MediaOrphanScannerTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: cleanupRoot, withIntermediateDirectories: true)
        mediaStore = MediaStore(
            mediaRootOverride: cleanupRoot.appending(path: "Media", directoryHint: .isDirectory),
            cachesRootOverride: cleanupRoot.appending(path: "Caches", directoryHint: .isDirectory)
        )
        scanner = MediaOrphanScanner(modelContext: context, mediaStore: mediaStore)
    }

    deinit {
        try? FileManager.default.removeItem(at: cleanupRoot)
    }

    @Test func consistentStoreScansClean() async throws {
        let image = TestImageFactory.makeImage(size: CGSize(width: 20, height: 20), color: .systemIndigo)
        let draft = try await mediaStore.writeAvatarOriginal(image, avatarID: UUID(), source: .camera)
        context.insert(ImageAsset(draft: draft))
        let thumbDraft = try await mediaStore.writeThumbnail(from: image)
        context.insert(ImageAsset(draft: thumbDraft))
        try context.save()

        let report = try await scanner.scan()

        #expect(!report.hasFindings)
        #expect(report == MediaOrphanScanReport())
    }

    @Test func rowWithoutFileIsReportedMissing() async throws {
        let image = TestImageFactory.makeImage(size: CGSize(width: 20, height: 20), color: .systemTeal)
        let draft = try await mediaStore.writeWardrobeOriginal(image, itemID: UUID(), source: .camera)
        context.insert(ImageAsset(draft: draft))
        try context.save()

        // Remove the file behind the store's back.
        await mediaStore.deleteFile(relativePath: draft.relativePath, kind: draft.kind)

        let report = try await scanner.scan()

        #expect(report.missingFilesByKind == [ImageAssetKind.wardrobeOriginal.rawValue: 1])
        #expect(report.orphanedDurableFileCount == 0)
    }

    @Test func fileWithoutRowIsReportedOrphaned() async throws {
        let image = TestImageFactory.makeImage(size: CGSize(width: 20, height: 20), color: .systemPink)
        // Write durable and cached files but never insert rows for them.
        _ = try await mediaStore.writeWardrobeOriginal(image, itemID: UUID(), source: .camera)
        _ = try await mediaStore.writeThumbnail(from: image)

        let report = try await scanner.scan()

        #expect(report.orphanedDurableFileCount == 1)
        #expect(report.orphanedCachedFileCount == 1)
        #expect(report.missingFilesByKind.isEmpty)
    }
}
