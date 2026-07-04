import SwiftData
import Testing
import UIKit
@testable import outfitloader

/// Saved-look transactions: create with preview and slots, hydrate back into
/// try-on state, refresh previews, and the wardrobe delete-blocking contract.
@MainActor
final class LookRepositoryTests {
    private let container: ModelContainer
    private let context: ModelContext
    private let mediaStore: MediaStore
    private let cleanupRoot: URL

    init() throws {
        container = try ModelContainerFactory.makeInMemory()
        context = ModelContext(container)

        cleanupRoot = FileManager.default.temporaryDirectory
            .appending(path: "LookRepositoryTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: cleanupRoot, withIntermediateDirectories: true)
        mediaStore = MediaStore(
            mediaRootOverride: cleanupRoot.appending(path: "Media", directoryHint: .isDirectory),
            cachesRootOverride: cleanupRoot.appending(path: "Caches", directoryHint: .isDirectory)
        )
    }

    deinit {
        try? FileManager.default.removeItem(at: cleanupRoot)
    }

    private func makeAvatar(image: UIImage) async throws -> AvatarProfile {
        let avatarID = UUID()
        let avatar = AvatarProfile(id: avatarID, processingStatus: .ready)
        avatar.silhouetteImage = ImageAsset(
            draft: try await mediaStore.writeAvatarSilhouette(image, avatarID: avatarID)
        )
        context.insert(avatar)
        return avatar
    }

    private func makeItem(named name: String, image: UIImage) async throws -> WardrobeItem {
        try await WardrobeRepository(modelContext: context, mediaStore: mediaStore).createItem(
            named: name,
            kind: .tops,
            originalImage: image,
            processedImage: nil,
            capturedFrom: .camera
        )
    }

    @Test func createLookPersistsPreviewSlotsAndHydratesComposition() async throws {
        let avatarImage = TestImageFactory.makeImage(size: CGSize(width: 64, height: 128), color: .systemBlue)
        let clothingImage = TestImageFactory.makeImage(size: CGSize(width: 48, height: 48), color: .systemRed)
        let avatar = try await makeAvatar(image: avatarImage)
        let item = try await makeItem(named: "Red Shirt", image: clothingImage)

        let composition = TryOnComposition()
        composition.avatarAdjustment = AvatarAdjustment(scale: 1.12, rotationRadians: .pi / 18, opacity: 0.82)
        composition.place(itemID: item.id, name: item.name, kind: .tops, image: clothingImage)
        let layerID = try #require(composition.sortedLayers.first?.id)
        composition.updatePlacement(layerID: layerID) { placement in
            placement.anchor = CGPoint(x: 0.42, y: 0.31)
            placement.scale = 0.58
            placement.rotationRadians = .pi / 12
            placement.opacity = 0.77
        }

        let lookRepository = LookRepository(modelContext: context, mediaStore: mediaStore)
        let look = try await lookRepository.createLook(
            named: "  Test Fit  ",
            avatar: avatar,
            avatarImage: avatarImage,
            composition: composition,
            wardrobeItems: [item]
        )

        #expect(look.name == "Test Fit")
        #expect(look.slots.count == 1)
        #expect(look.previewImage != nil)
        #expect(abs(look.avatarScale - 1.12) < 0.001)
        #expect(abs(look.avatarOpacity - 0.82) < 0.001)

        let hydrated = try await lookRepository.hydrateComposition(from: look)

        #expect(hydrated.layers.count == 1)
        #expect(abs(hydrated.avatarAdjustment.scale - 1.12) < 0.001)
        #expect(abs(hydrated.avatarAdjustment.opacity - 0.82) < 0.001)
        let layer = try #require(hydrated.layers.first)
        #expect(layer.itemID == item.id)
        #expect(abs(layer.placement.anchor.x - 0.42) < 0.001)
        #expect(abs(layer.placement.anchor.y - 0.31) < 0.001)
        #expect(abs(layer.placement.scale - 0.58) < 0.001)
        #expect(abs(layer.placement.opacity - 0.77) < 0.001)
    }

    @Test func createLookRejectsMissingWardrobeItem() async throws {
        let avatar = AvatarProfile(processingStatus: .ready)
        context.insert(avatar)

        let composition = TryOnComposition()
        composition.place(
            itemID: UUID(),
            name: "Missing Shirt",
            kind: .tops,
            image: TestImageFactory.makeImage(size: CGSize(width: 32, height: 32), color: .systemRed)
        )

        let repository = LookRepository(modelContext: context, mediaStore: mediaStore)

        await #expect(throws: LookRepositoryError.missingWardrobeItem("Missing Shirt")) {
            _ = try await repository.createLook(
                named: "Missing Item",
                avatar: avatar,
                avatarImage: TestImageFactory.makeImage(size: CGSize(width: 64, height: 128), color: .systemBlue),
                composition: composition,
                wardrobeItems: []
            )
        }
    }

    @Test func wardrobeDeleteIsBlockedWhenItemIsUsedBySavedLook() async throws {
        let avatarImage = TestImageFactory.makeImage(size: CGSize(width: 64, height: 128), color: .systemBlue)
        let clothingImage = TestImageFactory.makeImage(size: CGSize(width: 48, height: 48), color: .systemGreen)
        let avatar = try await makeAvatar(image: avatarImage)
        let item = try await makeItem(named: "Green Shirt", image: clothingImage)

        let composition = TryOnComposition()
        composition.place(itemID: item.id, name: item.name, kind: .tops, image: clothingImage)
        _ = try await LookRepository(modelContext: context, mediaStore: mediaStore).createLook(
            named: "Saved Look",
            avatar: avatar,
            avatarImage: avatarImage,
            composition: composition,
            wardrobeItems: [item]
        )

        let wardrobeRepository = WardrobeRepository(modelContext: context, mediaStore: mediaStore)
        await #expect(throws: WardrobeRepositoryError.itemUsedInLooks(count: 1)) {
            try await wardrobeRepository.deleteItem(item)
        }
    }

    @Test func refreshPreviewsRewritesOnlyLooksContainingTheItem() async throws {
        let avatarImage = TestImageFactory.makeImage(size: CGSize(width: 64, height: 128), color: .systemBlue)
        let redImage = TestImageFactory.makeImage(size: CGSize(width: 48, height: 48), color: .systemRed)
        let greenImage = TestImageFactory.makeImage(size: CGSize(width: 48, height: 48), color: .systemGreen)
        let avatar = try await makeAvatar(image: avatarImage)
        let redItem = try await makeItem(named: "Red Shirt", image: redImage)
        let greenItem = try await makeItem(named: "Green Shirt", image: greenImage)

        let lookRepository = LookRepository(modelContext: context, mediaStore: mediaStore)
        var looks: [OutfitLook] = []
        for item in [redItem, greenItem] {
            let composition = TryOnComposition()
            let image = item.id == redItem.id ? redImage : greenImage
            composition.place(itemID: item.id, name: item.name, kind: .tops, image: image)
            looks.append(try await lookRepository.createLook(
                named: "\(item.name) Look",
                avatar: avatar,
                avatarImage: avatarImage,
                composition: composition,
                wardrobeItems: [redItem, greenItem]
            ))
        }

        let redPreview = try #require(looks[0].previewImage)
        let greenPreview = try #require(looks[1].previewImage)
        let redUpdatedAt = redPreview.updatedAt
        let greenUpdatedAt = greenPreview.updatedAt
        let redPath = redPreview.relativePath

        await lookRepository.refreshPreviews(containing: redItem)

        // The containing look re-rendered in place: same path, newer stamp.
        #expect(redPreview.relativePath == redPath)
        #expect(redPreview.updatedAt > redUpdatedAt)
        #expect(greenPreview.updatedAt == greenUpdatedAt)
    }
}
