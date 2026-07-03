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
        category: ClosetCategory?,
        originalImage: UIImage,
        processedImage: UIImage?,
        capturedFrom source: ImageSource
    ) throws -> WardrobeItem {
        let itemID = UUID()

        let originalDraft: ImageAssetDraft
        var processedDraft: ImageAssetDraft?
        let thumbnailDraft: ImageAssetDraft
        do {
            originalDraft = try mediaStore.writeWardrobeOriginal(originalImage, itemID: itemID, source: source)
            if let processedImage {
                processedDraft = try mediaStore.writeWardrobeProcessed(processedImage, itemID: itemID)
            }
            thumbnailDraft = try mediaStore.writeThumbnail(from: processedImage ?? originalImage)
        } catch {
            mediaStore.deleteWardrobeMedia(itemID: itemID)
            throw error
        }

        let sortIndex = (try? modelContext.fetchCount(FetchDescriptor<WardrobeItem>())) ?? 0
        let item = WardrobeItem(id: itemID, name: name, kind: kind, sortIndex: sortIndex)
        item.category = category
        item.originalImage = ImageAsset(draft: originalDraft)
        item.processedImage = processedDraft.map { ImageAsset(draft: $0) }
        item.thumbnailImage = ImageAsset(draft: thumbnailDraft)
        modelContext.insert(item)

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            mediaStore.deleteWardrobeMedia(itemID: itemID)
            mediaStore.deleteFile(relativePath: thumbnailDraft.relativePath, kind: thumbnailDraft.kind)
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
    ) throws {
        let oldAssets = [item.originalImage, item.processedImage, item.thumbnailImage].compactMap { $0 }
        var newDrafts: [ImageAssetDraft] = []

        let originalDraft: ImageAssetDraft
        var processedDraft: ImageAssetDraft?
        let thumbnailDraft: ImageAssetDraft
        do {
            originalDraft = try mediaStore.writeWardrobeReplacementOriginal(originalImage, itemID: item.id, source: source)
            newDrafts.append(originalDraft)

            if let processedImage {
                processedDraft = try mediaStore.writeWardrobeReplacementProcessed(processedImage, itemID: item.id)
                if let processedDraft {
                    newDrafts.append(processedDraft)
                }
            }

            thumbnailDraft = try mediaStore.writeThumbnail(from: processedImage ?? originalImage)
            newDrafts.append(thumbnailDraft)
        } catch {
            deleteDrafts(newDrafts)
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
            deleteDrafts(newDrafts)
            throw error
        }

        for asset in oldAssets {
            mediaStore.deleteMedia(for: asset)
        }
    }

    func deleteItem(_ item: WardrobeItem) throws {
        let usageCount = try savedLookUsageCount(for: item)
        guard usageCount == 0 else {
            throw WardrobeRepositoryError.itemUsedInLooks(count: usageCount)
        }

        let assets = [item.originalImage, item.processedImage, item.thumbnailImage]
        for asset in assets.compactMap({ $0 }) {
            mediaStore.deleteMedia(for: asset)
        }
        mediaStore.deleteWardrobeMedia(itemID: item.id)
        modelContext.delete(item)
        try modelContext.save()
    }

    private func deleteDrafts(_ drafts: [ImageAssetDraft]) {
        for draft in drafts {
            mediaStore.deleteFile(relativePath: draft.relativePath, kind: draft.kind)
        }
    }
}
