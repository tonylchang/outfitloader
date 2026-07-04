import Foundation
import SwiftData
import UIKit

enum WardrobeRepositoryError: LocalizedError {
    case itemUsedInLooks(count: Int)

    var errorDescription: String? {
        switch self {
        case .itemUsedInLooks(let count):
            let label = count == 1 ? "look" : "looks"
            return "This item is used in \(count) saved \(label). Delete those looks before deleting this item."
        }
    }
}

/// Owns the transaction that keeps wardrobe SwiftData rows and media files
/// consistent. Deletion removes both the rows and the underlying files.
@MainActor
struct WardrobeRepository {
    let modelContext: ModelContext
    let mediaStore: MediaStore

    @discardableResult
    func createItem(
        named name: String,
        kind: CategoryKind,
        originalImage: UIImage,
        processedImage: UIImage?,
        capturedFrom source: ImageSource
    ) async throws -> WardrobeItem {
        let itemID = UUID()

        let originalDraft: ImageAssetDraft
        var processedDraft: ImageAssetDraft?
        let thumbnailDraft: ImageAssetDraft
        do {
            originalDraft = try await mediaStore.writeWardrobeOriginal(originalImage, itemID: itemID, source: source)
            if let processedImage {
                processedDraft = try await mediaStore.writeWardrobeProcessed(processedImage, itemID: itemID)
            }
            thumbnailDraft = try await mediaStore.writeThumbnail(from: processedImage ?? originalImage)
        } catch {
            await mediaStore.deleteWardrobeMedia(itemID: itemID)
            throw error
        }

        let item = WardrobeItem(id: itemID, name: name, kind: kind)
        item.originalImage = ImageAsset(draft: originalDraft)
        item.processedImage = processedDraft.map { ImageAsset(draft: $0) }
        item.thumbnailImage = ImageAsset(draft: thumbnailDraft)
        modelContext.insert(item)

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            await mediaStore.deleteWardrobeMedia(itemID: itemID)
            await mediaStore.deleteFile(relativePath: thumbnailDraft.relativePath, kind: thumbnailDraft.kind)
            throw error
        }

        return item
    }

    func savedLookUsageCount(for item: WardrobeItem) throws -> Int {
        let slots = try modelContext.fetch(FetchDescriptor<OutfitSlot>())
        let lookIDs = slots.reduce(into: Set<UUID>()) { result, slot in
            guard slot.wardrobeItem?.id == item.id,
                  let look = slot.look,
                  !look.isArchived
            else {
                return
            }

            result.insert(look.id)
        }

        return lookIDs.count
    }

    func replaceItemPhoto(
        _ item: WardrobeItem,
        originalImage: UIImage,
        processedImage: UIImage?,
        capturedFrom source: ImageSource
    ) async throws {
        let oldAssets = [item.originalImage, item.processedImage, item.thumbnailImage].compactMap { $0 }
        let oldFiles = mediaFiles(of: oldAssets)
        var newDrafts: [ImageAssetDraft] = []

        let originalDraft: ImageAssetDraft
        var processedDraft: ImageAssetDraft?
        let thumbnailDraft: ImageAssetDraft
        do {
            originalDraft = try await mediaStore.writeWardrobeReplacementOriginal(originalImage, itemID: item.id, source: source)
            newDrafts.append(originalDraft)

            if let processedImage {
                processedDraft = try await mediaStore.writeWardrobeReplacementProcessed(processedImage, itemID: item.id)
                if let processedDraft {
                    newDrafts.append(processedDraft)
                }
            }

            thumbnailDraft = try await mediaStore.writeThumbnail(from: processedImage ?? originalImage)
            newDrafts.append(thumbnailDraft)
        } catch {
            await deleteDrafts(newDrafts)
            throw error
        }

        item.originalImage = ImageAsset(draft: originalDraft)
        item.processedImage = processedDraft.map { ImageAsset(draft: $0) }
        item.thumbnailImage = ImageAsset(draft: thumbnailDraft)
        item.updatedAt = .now

        for asset in oldAssets {
            modelContext.delete(asset)
        }

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            await deleteDrafts(newDrafts)
            throw error
        }

        await deleteFiles(oldFiles)
    }

    func deleteItem(_ item: WardrobeItem) async throws {
        let usageCount = try savedLookUsageCount(for: item)
        guard usageCount == 0 else {
            throw WardrobeRepositoryError.itemUsedInLooks(count: usageCount)
        }

        let files = mediaFiles(of: [item.originalImage, item.processedImage, item.thumbnailImage].compactMap { $0 })
        let itemID = item.id
        modelContext.delete(item)
        try modelContext.save()

        await deleteFiles(files)
        await mediaStore.deleteWardrobeMedia(itemID: itemID)
    }

    /// File locations are captured while the models are alive and rows are
    /// deleted before files, so a failed save never leaves rows pointing at
    /// missing media. SwiftData models never cross into the actor.
    private func mediaFiles(of assets: [ImageAsset]) -> [(relativePath: String, kind: ImageAssetKind)] {
        assets.compactMap { asset in
            asset.kind.map { (relativePath: asset.relativePath, kind: $0) }
        }
    }

    private func deleteFiles(_ files: [(relativePath: String, kind: ImageAssetKind)]) async {
        for file in files {
            await mediaStore.deleteFile(relativePath: file.relativePath, kind: file.kind)
        }
    }

    private func deleteDrafts(_ drafts: [ImageAssetDraft]) async {
        for draft in drafts {
            await mediaStore.deleteFile(relativePath: draft.relativePath, kind: draft.kind)
        }
    }
}
