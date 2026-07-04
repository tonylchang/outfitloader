import Testing
import UIKit
@testable import outfitloader

/// Pure canvas-state logic: placement, category replacement, selection
/// follow-up, deterministic layer order, and reset.
@MainActor
struct TryOnCompositionTests {
    private let composition = TryOnComposition()

    private func image() -> UIImage {
        TestImageFactory.makeImage(size: CGSize(width: 10, height: 10), color: .systemRed)
    }

    @Test func placingAnItemSelectsItsLayer() {
        let itemID = UUID()

        composition.place(itemID: itemID, name: "Tee", kind: .tops, image: image())

        #expect(composition.layers.count == 1)
        #expect(composition.isPlaced(itemID: itemID))
        let layerID = composition.layers[0].id
        #expect(composition.selection == .layer(layerID))
    }

    @Test func placingReplacesTheItemInTheSameCategory() {
        let firstID = UUID()
        let secondID = UUID()

        composition.place(itemID: firstID, name: "Tee", kind: .tops, image: image())
        composition.place(itemID: secondID, name: "Blouse", kind: .tops, image: image())

        #expect(composition.layers.count == 1)
        #expect(!composition.isPlaced(itemID: firstID))
        #expect(composition.isPlaced(itemID: secondID))
    }

    @Test func sortedLayersFollowDeterministicCategoryOrder() {
        composition.place(itemID: UUID(), name: "Hat", kind: .accessories, image: image())
        composition.place(itemID: UUID(), name: "Tee", kind: .tops, image: image())
        composition.place(itemID: UUID(), name: "Jeans", kind: .bottoms, image: image())
        composition.place(itemID: UUID(), name: "Boots", kind: .shoes, image: image())

        let kinds = composition.sortedLayers.map(\.categoryKind)
        #expect(kinds == [.bottoms, .shoes, .tops, .accessories])
    }

    @Test func removingTheSelectedLayerFallsBackToAvatarSelection() {
        let itemID = UUID()
        composition.place(itemID: itemID, name: "Tee", kind: .tops, image: image())

        composition.remove(itemID: itemID)

        #expect(composition.layers.isEmpty)
        #expect(composition.selection == .avatar)
    }

    @Test func removingAnUnselectedLayerKeepsTheSelection() {
        let topsID = UUID()
        let shoesID = UUID()
        composition.place(itemID: topsID, name: "Tee", kind: .tops, image: image())
        composition.place(itemID: shoesID, name: "Boots", kind: .shoes, image: image())
        let selectedLayerID = composition.layers.first { $0.itemID == shoesID }?.id

        composition.remove(itemID: topsID)

        #expect(composition.selection == selectedLayerID.map { .layer($0) })
    }

    @Test func updatePlacementMutatesOnlyTheTargetLayer() throws {
        composition.place(itemID: UUID(), name: "Tee", kind: .tops, image: image())
        composition.place(itemID: UUID(), name: "Jeans", kind: .bottoms, image: image())
        let topsLayer = try #require(composition.layers.first { $0.categoryKind == .tops })
        let bottomsBefore = try #require(composition.layers.first { $0.categoryKind == .bottoms }).placement

        composition.updatePlacement(layerID: topsLayer.id) { $0.scale = 0.8 }

        #expect(composition.layer(id: topsLayer.id)?.placement.scale == 0.8)
        #expect(composition.layers.first { $0.categoryKind == .bottoms }?.placement == bottomsBefore)
    }

    @Test func loadSavedLookReplacesStateAndSelectsTheFirstLayer() {
        composition.place(itemID: UUID(), name: "Old Tee", kind: .tops, image: image())

        let savedLayer = TryOnLayer(
            id: UUID(),
            itemID: UUID(),
            itemName: "Saved Jeans",
            categoryKind: .bottoms,
            image: image(),
            placement: ClothingPlacement()
        )
        let savedAdjustment = AvatarAdjustment(scale: 1.2, rotationRadians: 0.1, opacity: 0.9)

        composition.loadSavedLook(avatarAdjustment: savedAdjustment, layers: [savedLayer])

        #expect(composition.layers.count == 1)
        #expect(composition.layers[0].itemID == savedLayer.itemID)
        #expect(composition.avatarAdjustment == savedAdjustment)
        #expect(composition.selection == .layer(savedLayer.id))
    }

    @Test func resetRestoresThePristineState() {
        composition.avatarAdjustment.scale = 1.3
        composition.place(itemID: UUID(), name: "Tee", kind: .tops, image: image())
        #expect(!composition.isPristine)
        #expect(composition.canSave)

        composition.reset()

        #expect(composition.isPristine)
        #expect(!composition.canSave)
        #expect(composition.selection == .avatar)
    }
}
