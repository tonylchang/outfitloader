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
    ) async throws -> OutfitLook {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard composition.canSave else {
            throw LookRepositoryError.emptyLook
        }

        // Resolve every layer to its wardrobe item before any file or row is
        // written, so a missing item can never abort mid-transaction.
        let itemsByID = Dictionary(uniqueKeysWithValues: wardrobeItems.map { ($0.id, $0) })
        let placedLayers: [(layer: TryOnLayer, item: WardrobeItem)] = try composition.sortedLayers.map { layer in
            guard let item = itemsByID[layer.itemID] else {
                throw LookRepositoryError.missingWardrobeItem(layer.itemName)
            }

            return (layer: layer, item: item)
        }

        let lookID = UUID()
        let renderLayers = placedLayers.map {
            OutfitRenderLayer(image: $0.layer.image, placement: $0.layer.placement, zIndex: $0.layer.zIndex)
        }
        let preview = TryOnComposer().compose(
            avatar: avatarImage,
            avatarAdjustment: composition.avatarAdjustment,
            layers: renderLayers
        )

        let previewDraft: ImageAssetDraft
        do {
            previewDraft = try await mediaStore.writeOutfitPreview(preview, lookID: lookID)
        } catch {
            await mediaStore.deleteOutfitMedia(lookID: lookID)
            throw error
        }

        let avatarAdjustment = composition.avatarAdjustment
        let look = OutfitLook(
            id: lookID,
            name: name.isEmpty ? "Untitled Look" : name,
            avatarScale: Double(avatarAdjustment.scale),
            avatarRotationDegrees: Double(avatarAdjustment.rotationRadians * 180 / .pi),
            avatarOpacity: Double(avatarAdjustment.opacity)
        )
        look.avatarProfile = avatar
        look.previewImage = ImageAsset(draft: previewDraft)
        modelContext.insert(look)

        for (layer, item) in placedLayers {
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
            await mediaStore.deleteOutfitMedia(lookID: lookID)
            throw error
        }

        return look
    }

    func hydrateComposition(from look: OutfitLook) async throws -> HydratedLookComposition {
        guard look.avatarProfile?.silhouetteImage ?? look.avatarProfile?.sourceImage != nil else {
            throw LookRepositoryError.missingAvatar
        }

        let layers = try await hydrateSlots(of: look).map { hydrated in
            TryOnLayer(
                id: hydrated.slot.id,
                itemID: hydrated.item.id,
                itemName: hydrated.item.name,
                categoryKind: hydrated.slot.categoryKind ?? hydrated.item.categoryKind ?? .tops,
                image: hydrated.image,
                placement: hydrated.placement
            )
        }

        return HydratedLookComposition(
            avatarAdjustment: look.savedAvatarAdjustment,
            layers: layers
        )
    }

    func deleteLook(_ look: OutfitLook) async throws {
        let lookID = look.id
        modelContext.delete(look)
        try modelContext.save()
        await mediaStore.deleteOutfitMedia(lookID: lookID)
    }

    func refreshPreviews(containing item: WardrobeItem) async {
        let itemID = item.id
        guard let slots = try? modelContext.fetch(
            FetchDescriptor<OutfitSlot>(predicate: #Predicate { $0.wardrobeItem?.id == itemID })
        ) else {
            return
        }

        var seenLookIDs: Set<UUID> = []
        let looks = slots.compactMap { slot -> OutfitLook? in
            guard let look = slot.look, !look.isArchived, seenLookIDs.insert(look.id).inserted else {
                return nil
            }

            return look
        }

        for look in looks {
            do {
                try await refreshPreview(for: look)
                try modelContext.save()
            } catch {
                modelContext.rollback()
            }
        }
    }

    /// One saved slot resolved to live data, in z order: the wardrobe item,
    /// its display image, and the stored placement.
    private struct HydratedSlot {
        let slot: OutfitSlot
        let item: WardrobeItem
        let image: UIImage
        let placement: ClothingPlacement
    }

    /// Single hydration path for reopening looks and re-rendering previews,
    /// so the two flows cannot drift in how they resolve saved slots.
    private func hydrateSlots(of look: OutfitLook) async throws -> [HydratedSlot] {
        try await look.slots
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

                return HydratedSlot(
                    slot: slot,
                    item: item,
                    image: image,
                    placement: ClothingPlacement(
                        anchor: CGPoint(x: slot.anchorX, y: slot.anchorY),
                        scale: CGFloat(slot.scale),
                        rotationRadians: CGFloat(slot.rotationDegrees) * .pi / 180,
                        opacity: CGFloat(slot.opacity)
                    )
                )
            }
    }

    private func loadImage(for asset: ImageAsset) async -> UIImage? {
        await mediaStore.loadImage(relativePath: asset.relativePath, kindRawValue: asset.kindRawValue)
    }

    private func refreshPreview(for look: OutfitLook) async throws {
        guard let avatarAsset = look.avatarProfile?.silhouetteImage ?? look.avatarProfile?.sourceImage,
              let avatarImage = await loadImage(for: avatarAsset)
        else {
            throw LookRepositoryError.missingAvatar
        }
        let renderedAvatar = AvatarBodyShapeRenderer().render(
            avatarImage,
            adjustment: look.avatarProfile?.bodyShapeAdjustment ?? .neutral
        )

        let renderLayers = try await hydrateSlots(of: look).map { hydrated in
            OutfitRenderLayer(image: hydrated.image, placement: hydrated.placement, zIndex: hydrated.slot.zIndex)
        }

        let preview = TryOnComposer().compose(
            avatar: renderedAvatar,
            avatarAdjustment: look.savedAvatarAdjustment,
            layers: renderLayers
        )
        let previewDraft = try await mediaStore.writeOutfitPreview(preview, lookID: look.id)

        if let previewImage = look.previewImage {
            previewImage.apply(previewDraft)
        } else {
            look.previewImage = ImageAsset(draft: previewDraft)
        }

        look.updatedAt = .now
    }
}

private extension OutfitLook {
    /// The avatar transform captured when the look was saved.
    var savedAvatarAdjustment: AvatarAdjustment {
        AvatarAdjustment(
            scale: CGFloat(avatarScale),
            rotationRadians: CGFloat(avatarRotationDegrees) * .pi / 180,
            opacity: CGFloat(avatarOpacity)
        )
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

private extension ImageAsset {
    func apply(_ draft: ImageAssetDraft) {
        updatedAt = .now
        kindRawValue = draft.kind.rawValue
        relativePath = draft.relativePath
        contentType = draft.contentType
        pixelWidth = draft.pixelWidth
        pixelHeight = draft.pixelHeight
        byteCount = draft.byteCount
        sourceRawValue = draft.source.rawValue
        sha256 = draft.sha256
        isRegenerable = draft.isRegenerable
    }
}
