import SwiftData
import UIKit
import XCTest
@testable import outfitloader

@MainActor
final class LookRepositoryTests: XCTestCase {
    func testCreateLookPersistsPreviewSlotsAndHydratesComposition() async throws {
        let store = try InMemoryStore()
        let mediaStore = MediaStore()
        let avatarID = UUID()
        let avatarImage = TestImageFactory.makeImage(size: CGSize(width: 64, height: 128), color: .systemBlue)
        let clothingImage = TestImageFactory.makeImage(size: CGSize(width: 48, height: 48), color: .systemRed)
        defer {
            mediaStore.deleteAvatarMedia(avatarID: avatarID)
        }

        let avatar = AvatarProfile(id: avatarID, processingStatus: .ready)
        avatar.silhouetteImage = ImageAsset(
            draft: try mediaStore.writeAvatarSilhouette(avatarImage, avatarID: avatarID)
        )
        store.context.insert(avatar)

        let wardrobeRepository = WardrobeRepository(modelContext: store.context, mediaStore: mediaStore)
        let item = try wardrobeRepository.createItem(
            named: "Red Shirt",
            kind: .tops,
            category: nil,
            originalImage: clothingImage,
            processedImage: nil,
            capturedFrom: .photoLibrary
        )
        defer {
            mediaStore.deleteWardrobeMedia(itemID: item.id)
        }

        let composition = TryOnComposition()
        composition.avatarAdjustment = AvatarAdjustment(scale: 1.12, rotationRadians: .pi / 18, opacity: 0.82)
        composition.place(itemID: item.id, name: item.name, kind: .tops, image: clothingImage)
        let layerID = try XCTUnwrap(composition.sortedLayers.first?.id)
        composition.updatePlacement(layerID: layerID) { placement in
            placement.anchor = CGPoint(x: 0.42, y: 0.31)
            placement.scale = 0.58
            placement.rotationRadians = .pi / 12
            placement.opacity = 0.77
        }

        let lookRepository = LookRepository(modelContext: store.context, mediaStore: mediaStore)
        let look = try lookRepository.createLook(
            named: "  Test Fit  ",
            avatar: avatar,
            avatarImage: avatarImage,
            composition: composition,
            wardrobeItems: [item]
        )
        defer {
            mediaStore.deleteOutfitMedia(lookID: look.id)
        }

        XCTAssertEqual(look.name, "Test Fit")
        XCTAssertEqual(look.slots.count, 1)
        XCTAssertNotNil(look.previewImage)
        XCTAssertEqual(look.avatarScale, 1.12, accuracy: 0.001)
        XCTAssertEqual(look.avatarOpacity, 0.82, accuracy: 0.001)

        let hydrated = try await lookRepository.hydrateComposition(from: look)

        XCTAssertEqual(hydrated.layers.count, 1)
        XCTAssertEqual(hydrated.avatarAdjustment.scale, 1.12, accuracy: 0.001)
        XCTAssertEqual(hydrated.avatarAdjustment.opacity, 0.82, accuracy: 0.001)
        XCTAssertEqual(hydrated.layers[0].itemID, item.id)
        XCTAssertEqual(hydrated.layers[0].placement.anchor.x, 0.42, accuracy: 0.001)
        XCTAssertEqual(hydrated.layers[0].placement.anchor.y, 0.31, accuracy: 0.001)
        XCTAssertEqual(hydrated.layers[0].placement.scale, 0.58, accuracy: 0.001)
        XCTAssertEqual(hydrated.layers[0].placement.opacity, 0.77, accuracy: 0.001)
    }

    func testCreateLookRejectsMissingWardrobeItem() throws {
        let store = try InMemoryStore()
        let mediaStore = MediaStore()
        let avatar = AvatarProfile(processingStatus: .ready)
        store.context.insert(avatar)

        let composition = TryOnComposition()
        composition.place(
            itemID: UUID(),
            name: "Missing Shirt",
            kind: .tops,
            image: TestImageFactory.makeImage(size: CGSize(width: 32, height: 32), color: .systemRed)
        )

        let repository = LookRepository(modelContext: store.context, mediaStore: mediaStore)

        XCTAssertThrowsError(
            try repository.createLook(
                named: "Missing Item",
                avatar: avatar,
                avatarImage: TestImageFactory.makeImage(size: CGSize(width: 64, height: 128), color: .systemBlue),
                composition: composition,
                wardrobeItems: []
            )
        ) { error in
            XCTAssertEqual(error.localizedDescription, "Missing Shirt is no longer available in the closet.")
        }
    }

    func testWardrobeDeleteIsBlockedWhenItemIsUsedBySavedLook() throws {
        let store = try InMemoryStore()
        let mediaStore = MediaStore()
        let avatarID = UUID()
        let avatarImage = TestImageFactory.makeImage(size: CGSize(width: 64, height: 128), color: .systemBlue)
        let clothingImage = TestImageFactory.makeImage(size: CGSize(width: 48, height: 48), color: .systemGreen)
        defer {
            mediaStore.deleteAvatarMedia(avatarID: avatarID)
        }

        let avatar = AvatarProfile(id: avatarID, processingStatus: .ready)
        avatar.silhouetteImage = ImageAsset(
            draft: try mediaStore.writeAvatarSilhouette(avatarImage, avatarID: avatarID)
        )
        store.context.insert(avatar)

        let wardrobeRepository = WardrobeRepository(modelContext: store.context, mediaStore: mediaStore)
        let item = try wardrobeRepository.createItem(
            named: "Green Shirt",
            kind: .tops,
            category: nil,
            originalImage: clothingImage,
            processedImage: nil,
            capturedFrom: .camera
        )
        defer {
            mediaStore.deleteWardrobeMedia(itemID: item.id)
        }

        let composition = TryOnComposition()
        composition.place(itemID: item.id, name: item.name, kind: .tops, image: clothingImage)
        let look = try LookRepository(modelContext: store.context, mediaStore: mediaStore).createLook(
            named: "Saved Look",
            avatar: avatar,
            avatarImage: avatarImage,
            composition: composition,
            wardrobeItems: [item]
        )
        defer {
            mediaStore.deleteOutfitMedia(lookID: look.id)
        }

        XCTAssertThrowsError(try wardrobeRepository.deleteItem(item)) { error in
            XCTAssertEqual(
                error.localizedDescription,
                "This item is used in 1 saved look. Delete those looks before deleting this item."
            )
        }
    }
}

private struct InMemoryStore {
    let container: ModelContainer
    let context: ModelContext

    @MainActor
    init() throws {
        container = try ModelContainerFactory.makeInMemory()
        context = ModelContext(container)
    }
}
