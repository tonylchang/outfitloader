import SwiftData
import Testing
import UIKit
@testable import outfitloader

/// The delete-everything contract behind Settings: user rows and media go,
/// system seed data stays.
@MainActor
final class LocalDataRepositoryTests {
    private let container: ModelContainer
    private let context: ModelContext
    private let mediaStore: MediaStore
    private let cleanupRoot: URL

    init() throws {
        container = try ModelContainerFactory.makeInMemory()
        context = ModelContext(container)

        cleanupRoot = FileManager.default.temporaryDirectory
            .appending(path: "LocalDataRepositoryTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: cleanupRoot, withIntermediateDirectories: true)
        mediaStore = MediaStore(
            mediaRootOverride: cleanupRoot.appending(path: "Media", directoryHint: .isDirectory),
            cachesRootOverride: cleanupRoot.appending(path: "Caches", directoryHint: .isDirectory)
        )
    }

    deinit {
        try? FileManager.default.removeItem(at: cleanupRoot)
    }

    @Test func deleteAllUserDataClearsRowsAndMediaButKeepsSeedCategories() async throws {
        try SeedData.seedDefaultCategories(in: context)

        let avatarImage = TestImageFactory.makeImage(size: CGSize(width: 64, height: 128), color: .systemBlue)
        let clothingImage = TestImageFactory.makeImage(size: CGSize(width: 48, height: 48), color: .systemRed)

        let avatar = try await AvatarRepository(modelContext: context, mediaStore: mediaStore).createAvatar(
            sourceImage: avatarImage,
            silhouetteImage: avatarImage,
            capturedFrom: .camera
        )
        let item = try await WardrobeRepository(modelContext: context, mediaStore: mediaStore).createItem(
            named: "Red Tee",
            kind: .tops,
            originalImage: clothingImage,
            processedImage: nil,
            capturedFrom: .camera
        )
        let composition = TryOnComposition()
        composition.place(itemID: item.id, name: item.name, kind: .tops, image: clothingImage)
        _ = try await LookRepository(modelContext: context, mediaStore: mediaStore).createLook(
            named: "Morning Look",
            avatar: avatar,
            avatarImage: avatarImage,
            composition: composition,
            wardrobeItems: [item]
        )

        try await LocalDataRepository(modelContext: context, mediaStore: mediaStore).deleteAllUserData()

        #expect(try context.fetchCount(FetchDescriptor<AvatarProfile>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<WardrobeItem>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<OutfitLook>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<OutfitSlot>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<ImageAsset>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<ClosetCategory>()) == CategoryKind.allCases.count)

        let onDisk = await mediaStore.listAllRelativePaths()
        #expect(onDisk.durable.isEmpty)
        #expect(onDisk.cached.isEmpty)
    }
}
