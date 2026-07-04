import SwiftData
import UIKit
import XCTest
@testable import outfitloader

@MainActor
final class LookRepositoryTests: XCTestCase {
    private var store: InMemoryStore!
    private var mediaStore: MediaStore!

    override func setUp() async throws {
        store = try InMemoryStore()

        let base = FileManager.default.temporaryDirectory
            .appending(path: "LookRepositoryTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        mediaStore = MediaStore(
            mediaRootOverride: base.appending(path: "Media", directoryHint: .isDirectory),
            cachesRootOverride: base.appending(path: "Caches", directoryHint: .isDirectory)
        )
        addTeardownBlock {
            try? FileManager.default.removeItem(at: base)
        }
    }

    func testCreateLookPersistsPreviewSlotsAndHydratesComposition() async throws {
        let avatarID = UUID()
        let avatarImage = TestImageFactory.makeImage(size: CGSize(width: 64, height: 128), color: .systemBlue)
        let clothingImage = TestImageFactory.makeImage(size: CGSize(width: 48, height: 48), color: .systemRed)

        let avatar = AvatarProfile(id: avatarID, processingStatus: .ready)
        avatar.silhouetteImage = ImageAsset(
            draft: try await mediaStore.writeAvatarSilhouette(avatarImage, avatarID: avatarID)
        )
        store.context.insert(avatar)

        let wardrobeRepository = WardrobeRepository(modelContext: store.context, mediaStore: mediaStore)
        let item = try await wardrobeRepository.createItem(
            named: "Red Shirt",
            kind: .tops,
            category: nil,
            originalImage: clothingImage,
            processedImage: nil,
            capturedFrom: .photoLibrary
        )

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
        let look = try await lookRepository.createLook(
            named: "  Test Fit  ",
            avatar: avatar,
            avatarImage: avatarImage,
            composition: composition,
            wardrobeItems: [item]
        )

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

    func testCreateLookRejectsMissingWardrobeItem() async throws {
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

        do {
            _ = try await repository.createLook(
                named: "Missing Item",
                avatar: avatar,
                avatarImage: TestImageFactory.makeImage(size: CGSize(width: 64, height: 128), color: .systemBlue),
                composition: composition,
                wardrobeItems: []
            )
            XCTFail("Expected createLook to throw for a missing wardrobe item")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Missing Shirt is no longer available in the closet.")
        }
    }

    func testWardrobeDeleteIsBlockedWhenItemIsUsedBySavedLook() async throws {
        let avatarID = UUID()
        let avatarImage = TestImageFactory.makeImage(size: CGSize(width: 64, height: 128), color: .systemBlue)
        let clothingImage = TestImageFactory.makeImage(size: CGSize(width: 48, height: 48), color: .systemGreen)

        let avatar = AvatarProfile(id: avatarID, processingStatus: .ready)
        avatar.silhouetteImage = ImageAsset(
            draft: try await mediaStore.writeAvatarSilhouette(avatarImage, avatarID: avatarID)
        )
        store.context.insert(avatar)

        let wardrobeRepository = WardrobeRepository(modelContext: store.context, mediaStore: mediaStore)
        let item = try await wardrobeRepository.createItem(
            named: "Green Shirt",
            kind: .tops,
            category: nil,
            originalImage: clothingImage,
            processedImage: nil,
            capturedFrom: .camera
        )

        let composition = TryOnComposition()
        composition.place(itemID: item.id, name: item.name, kind: .tops, image: clothingImage)
        _ = try await LookRepository(modelContext: store.context, mediaStore: mediaStore).createLook(
            named: "Saved Look",
            avatar: avatar,
            avatarImage: avatarImage,
            composition: composition,
            wardrobeItems: [item]
        )

        do {
            try await wardrobeRepository.deleteItem(item)
            XCTFail("Expected deleteItem to throw while the item is used by a saved look")
        } catch {
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
