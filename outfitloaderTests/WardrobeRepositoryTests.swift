import SwiftData
import Testing
import UIKit
@testable import outfitloader

/// Repository transaction tests: SwiftData rows and media files must stay
/// consistent through create, replace-photo, and delete.
@MainActor
final class WardrobeRepositoryTests {
    private let container: ModelContainer
    private let context: ModelContext
    private let mediaStore: MediaStore
    private let repository: WardrobeRepository
    private let cleanupRoot: URL

    init() throws {
        container = try ModelContainerFactory.makeInMemory()
        context = ModelContext(container)

        cleanupRoot = FileManager.default.temporaryDirectory
            .appending(path: "WardrobeRepositoryTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: cleanupRoot, withIntermediateDirectories: true)
        mediaStore = MediaStore(
            mediaRootOverride: cleanupRoot.appending(path: "Media", directoryHint: .isDirectory),
            cachesRootOverride: cleanupRoot.appending(path: "Caches", directoryHint: .isDirectory)
        )
        repository = WardrobeRepository(modelContext: context, mediaStore: mediaStore)
    }

    deinit {
        try? FileManager.default.removeItem(at: cleanupRoot)
    }

    @Test func createItemPersistsRowAssetsAndFiles() async throws {
        let original = TestImageFactory.makeImage(size: CGSize(width: 60, height: 60), color: .systemRed)
        let processed = TestImageFactory.makeImage(size: CGSize(width: 50, height: 50), color: .systemGreen)

        let item = try await repository.createItem(
            named: "Red Tee",
            kind: .tops,
            originalImage: original,
            processedImage: processed,
            capturedFrom: .camera
        )

        #expect(try context.fetchCount(FetchDescriptor<WardrobeItem>()) == 1)
        let originalAsset = try #require(item.originalImage)
        let processedAsset = try #require(item.processedImage)
        let thumbnailAsset = try #require(item.thumbnailImage)

        // The transparent cutout wins for display when it exists.
        #expect(item.displayImage === processedAsset)

        for asset in [originalAsset, processedAsset, thumbnailAsset] {
            let loaded = await mediaStore.loadImage(relativePath: asset.relativePath, kindRawValue: asset.kindRawValue)
            #expect(loaded != nil, "expected media file for \(asset.kindRawValue)")
        }
    }

    @Test func createItemWithoutProcessedImageFallsBackToOriginalForDisplay() async throws {
        let original = TestImageFactory.makeImage(size: CGSize(width: 60, height: 60), color: .systemBlue)

        let item = try await repository.createItem(
            named: "Uncut Jacket",
            kind: .tops,
            originalImage: original,
            processedImage: nil,
            capturedFrom: .photoLibrary
        )

        #expect(item.processedImage == nil)
        #expect(item.displayImage === item.originalImage)
    }

    @Test func deleteItemRemovesRowAssetsAndFiles() async throws {
        let original = TestImageFactory.makeImage(size: CGSize(width: 60, height: 60), color: .systemOrange)
        let item = try await repository.createItem(
            named: "Doomed Shirt",
            kind: .tops,
            originalImage: original,
            processedImage: nil,
            capturedFrom: .camera
        )
        let files = [item.originalImage, item.thumbnailImage].compactMap { asset in
            asset.map { (relativePath: $0.relativePath, kindRawValue: $0.kindRawValue) }
        }
        #expect(files.count == 2)

        try await repository.deleteItem(item)

        #expect(try context.fetchCount(FetchDescriptor<WardrobeItem>()) == 0)
        for file in files {
            let loaded = await mediaStore.loadImage(relativePath: file.relativePath, kindRawValue: file.kindRawValue)
            #expect(loaded == nil, "expected \(file.relativePath) to be deleted")
        }
    }

    @Test func replaceItemPhotoSwapsAssetsAndRemovesOldFiles() async throws {
        let item = try await repository.createItem(
            named: "Swapped Hoodie",
            kind: .tops,
            originalImage: TestImageFactory.makeImage(size: CGSize(width: 60, height: 60), color: .systemRed),
            processedImage: TestImageFactory.makeImage(size: CGSize(width: 50, height: 50), color: .systemGreen),
            capturedFrom: .camera
        )
        let oldFiles = [item.originalImage, item.processedImage, item.thumbnailImage].compactMap { asset in
            asset.map { (relativePath: $0.relativePath, kindRawValue: $0.kindRawValue) }
        }
        #expect(oldFiles.count == 3)

        try await repository.replaceItemPhoto(
            item,
            originalImage: TestImageFactory.makeImage(size: CGSize(width: 70, height: 70), color: .systemPurple),
            processedImage: TestImageFactory.makeImage(size: CGSize(width: 65, height: 65), color: .systemTeal),
            capturedFrom: .photoLibrary
        )

        let newAssets = [item.originalImage, item.processedImage, item.thumbnailImage].compactMap { $0 }
        #expect(newAssets.count == 3)
        for asset in newAssets {
            #expect(!oldFiles.contains { $0.relativePath == asset.relativePath })
            let loaded = await mediaStore.loadImage(relativePath: asset.relativePath, kindRawValue: asset.kindRawValue)
            #expect(loaded != nil, "expected replacement media for \(asset.kindRawValue)")
        }

        for file in oldFiles {
            let loaded = await mediaStore.loadImage(relativePath: file.relativePath, kindRawValue: file.kindRawValue)
            #expect(loaded == nil, "expected old media \(file.relativePath) to be removed")
        }

        // Old asset rows must not linger: one item leaves exactly three assets.
        #expect(try context.fetchCount(FetchDescriptor<ImageAsset>()) == 3)
    }
}
