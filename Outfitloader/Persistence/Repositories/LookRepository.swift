import Foundation
import SwiftData
import UIKit

enum LookRepositoryError: LocalizedError {
    case emptyLook
    case missingAvatar
    case missingWardrobeItem(String)
    case missingImage(String)

    var errorDescription: String? {
        switch self {
        case .emptyLook:
            return "Add at least one clothing item before saving a look."
        case .missingAvatar:
            return "The active avatar image could not be loaded."
        case .missingWardrobeItem(let itemName):
            return "\(itemName) is no longer available in the closet."
        case .missingImage(let itemName):
            return "The image for \(itemName) could not be loaded."
        }
    }
}

struct HydratedLookComposition {
    let avatarAdjustment: AvatarAdjustment
    let layers: [TryOnLayer]
}

/// Persists saved looks and reconstructs try-on state from saved slots.
/// Media is written before SwiftData rows are inserted; generated outfit
/// previews are cleaned up if the SwiftData transaction fails.
@MainActor
struct LookRepository {
    let modelContext: ModelContext
    let mediaStore: MediaStore

    @discardableResult
    func createLook(
        named rawName: String,
        avatar: AvatarProfile,
        avatarImage: UIImage,
        composition: TryOnComposition,
        wardrobeItems: [WardrobeItem]
    ) throws -> OutfitLook {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard composition.canSave else {
            throw LookRepositoryError.emptyLook
        }

        let itemsByID = Dictionary(uniqueKeysWithValues: wardrobeItems.map { ($0.id, $0) })
        let sortedLayers = composition.sortedLayers
        for layer in sortedLayers where itemsByID[layer.itemID] == nil {
            throw LookRepositoryError.missingWardrobeItem(layer.itemName)
        }

        let lookID = UUID()
        let renderLayers = sortedLayers.map {
            OutfitRenderLayer(image: $0.image, placement: $0.placement, zIndex: $0.zIndex)
        }
        let preview = TryOnComposer().compose(
            avatar: avatarImage,
            avatarAdjustment: composition.avatarAdjustment,
            layers: renderLayers
        )

        let previewDraft: ImageAssetDraft
        do {
            previewDraft = try mediaStore.writeOutfitPreview(preview, lookID: lookID)
        } catch {
            mediaStore.deleteOutfitMedia(lookID: lookID)
            throw error
        }

        let sortIndex = (try? modelContext.fetchCount(FetchDescriptor<OutfitLook>())) ?? 0
        let avatarAdjustment = composition.avatarAdjustment
        let look = OutfitLook(
            id: lookID,
            name: name.isEmpty ? "Untitled Look" : name,
            avatarScale: Double(avatarAdjustment.scale),
            avatarRotationDegrees: Double(avatarAdjustment.rotationRadians * 180 / .pi),
            avatarOpacity: Double(avatarAdjustment.opacity),
            sortIndex: sortIndex
        )
        look.avatarProfile = avatar
        look.previewImage = ImageAsset(draft: previewDraft)
        modelContext.insert(look)

        for layer in sortedLayers {
            guard let item = itemsByID[layer.itemID] else {
                throw LookRepositoryError.missingWardrobeItem(layer.itemName)
            }

            let placement = layer.placement
            let slot = OutfitSlot(
                kind: layer.categoryKind,
                zIndex: layer.zIndex,
                anchorX: placement.anchor.x,
                anchorY: placement.anchor.y,
                scale: Double(placement.scale),
                rotationDegrees: Double(placement.rotationRadians * 180 / .pi),
                opacity: Double(placement.opacity)
            )
            slot.look = look
            slot.wardrobeItem = item
            look.slots.append(slot)
            modelContext.insert(slot)
        }

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            mediaStore.deleteOutfitMedia(lookID: lookID)
            throw error
        }

        return look
    }

    func hydrateComposition(from look: OutfitLook) async throws -> HydratedLookComposition {
        guard let avatarAsset = look.avatarProfile?.silhouetteImage ?? look.avatarProfile?.sourceImage else {
            throw LookRepositoryError.missingAvatar
        }

        guard await loadImage(for: avatarAsset) != nil else {
            throw LookRepositoryError.missingAvatar
        }

        let layers = try await look.slots
            .sorted { $0.zIndex < $1.zIndex }
            .asyncMap { slot in
                guard let item = slot.wardrobeItem else {
                    throw LookRepositoryError.missingWardrobeItem(slot.categoryKind?.displayName ?? "Clothing item")
                }

                guard let asset = item.displayImage,
                      let image = await loadImage(for: asset)
                else {
                    throw LookRepositoryError.missingImage(item.name)
                }

                let kind = slot.categoryKind ?? item.categoryKind ?? .tops
                return TryOnLayer(
                    id: slot.id,
                    itemID: item.id,
                    itemName: item.name,
                    categoryKind: kind,
                    image: image,
                    placement: ClothingPlacement(
                        anchor: CGPoint(x: slot.anchorX, y: slot.anchorY),
                        scale: CGFloat(slot.scale),
                        rotationRadians: CGFloat(slot.rotationDegrees) * .pi / 180,
                        opacity: CGFloat(slot.opacity)
                    )
                )
            }

        return HydratedLookComposition(
            avatarAdjustment: AvatarAdjustment(
                scale: CGFloat(look.avatarScale),
                rotationRadians: CGFloat(look.avatarRotationDegrees) * .pi / 180,
                opacity: CGFloat(look.avatarOpacity)
            ),
            layers: layers
        )
    }

    func deleteLook(_ look: OutfitLook) throws {
        mediaStore.deleteOutfitMedia(lookID: look.id)
        modelContext.delete(look)
        try modelContext.save()
    }

    private func loadImage(for asset: ImageAsset) async -> UIImage? {
        let store = mediaStore
        let relativePath = asset.relativePath
        let kindRawValue = asset.kindRawValue
        return await Task.detached(priority: .userInitiated) {
            store.loadImage(relativePath: relativePath, kindRawValue: kindRawValue)
        }.value
    }
}

private extension Sequence {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async throws -> [T] {
        var values: [T] = []
        values.reserveCapacity(underestimatedCount)
        for element in self {
            let value = try await transform(element)
            values.append(value)
        }
        return values
    }
}
