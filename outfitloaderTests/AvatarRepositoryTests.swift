import SwiftData
import Testing
import UIKit
@testable import outfitloader

/// Avatar transactions: create with and without a silhouette, single-active
/// enforcement, and delete cleaning up rows and media together.
@MainActor
final class AvatarRepositoryTests {
    private let container: ModelContainer
    private let context: ModelContext
    private let mediaStore: MediaStore
    private let repository: AvatarRepository
    private let cleanupRoot: URL

    init() throws {
        container = try ModelContainerFactory.makeInMemory()
        context = ModelContext(container)

        cleanupRoot = FileManager.default.temporaryDirectory
            .appending(path: "AvatarRepositoryTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: cleanupRoot, withIntermediateDirectories: true)
        mediaStore = MediaStore(
            mediaRootOverride: cleanupRoot.appending(path: "Media", directoryHint: .isDirectory),
            cachesRootOverride: cleanupRoot.appending(path: "Caches", directoryHint: .isDirectory)
        )
        repository = AvatarRepository(modelContext: context, mediaStore: mediaStore)
    }

    deinit {
        try? FileManager.default.removeItem(at: cleanupRoot)
    }

    @Test func createAvatarPersistsRowAssetsAndFiles() async throws {
        let source = TestImageFactory.makeImage(size: CGSize(width: 60, height: 120), color: .systemBlue)
        let silhouette = TestImageFactory.makeImage(size: CGSize(width: 60, height: 120), color: .systemPurple)

        let profile = try await repository.createAvatar(
            sourceImage: source,
            silhouetteImage: silhouette,
            capturedFrom: .camera
        )

        #expect(profile.isActive)
        #expect(profile.processingStatus == .ready)
        let sourceAsset = try #require(profile.sourceImage)
        let silhouetteAsset = try #require(profile.silhouetteImage)
        for asset in [sourceAsset, silhouetteAsset] {
            let loaded = await mediaStore.loadImage(relativePath: asset.relativePath, kindRawValue: asset.kindRawValue)
            #expect(loaded != nil, "expected media file for \(asset.kindRawValue)")
        }
    }

    @Test func createAvatarWithoutSilhouetteIsMarkedFailed() async throws {
        let source = TestImageFactory.makeImage(size: CGSize(width: 60, height: 120), color: .systemBlue)

        let profile = try await repository.createAvatar(
            sourceImage: source,
            silhouetteImage: nil,
            capturedFrom: .photoLibrary
        )

        #expect(profile.processingStatus == .failed)
        #expect(profile.silhouetteImage == nil)
        #expect(profile.sourceImage != nil)
    }

    @Test func creatingASecondAvatarDeactivatesThePrevious() async throws {
        let source = TestImageFactory.makeImage(size: CGSize(width: 60, height: 120), color: .systemBlue)

        let first = try await repository.createAvatar(sourceImage: source, silhouetteImage: nil, capturedFrom: .camera)
        let second = try await repository.createAvatar(sourceImage: source, silhouetteImage: nil, capturedFrom: .camera)

        #expect(!first.isActive)
        #expect(second.isActive)

        let active = try context.fetch(
            FetchDescriptor<AvatarProfile>(predicate: #Predicate { $0.isActive })
        )
        #expect(active.count == 1)
        #expect(active.first?.id == second.id)
    }

    @Test func deleteAvatarRemovesRowAssetsAndFiles() async throws {
        let source = TestImageFactory.makeImage(size: CGSize(width: 60, height: 120), color: .systemBlue)
        let silhouette = TestImageFactory.makeImage(size: CGSize(width: 60, height: 120), color: .systemPurple)
        let profile = try await repository.createAvatar(
            sourceImage: source,
            silhouetteImage: silhouette,
            capturedFrom: .camera
        )
        let files = [profile.sourceImage, profile.silhouetteImage].compactMap { asset in
            asset.map { (relativePath: $0.relativePath, kindRawValue: $0.kindRawValue) }
        }
        #expect(files.count == 2)

        try await repository.deleteAvatar(profile)

        #expect(try context.fetchCount(FetchDescriptor<AvatarProfile>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<ImageAsset>()) == 0)
        for file in files {
            let loaded = await mediaStore.loadImage(relativePath: file.relativePath, kindRawValue: file.kindRawValue)
            #expect(loaded == nil, "expected \(file.relativePath) to be deleted")
        }
    }
}
