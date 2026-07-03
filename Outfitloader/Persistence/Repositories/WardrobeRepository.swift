import Foundation
import SwiftData
import UIKit

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

    func deleteItem(_ item: WardrobeItem) throws {
        let assets = [item.originalImage, item.processedImage, item.thumbnailImage, item.maskImage]
        for asset in assets.compactMap({ $0 }) {
            mediaStore.deleteMedia(for: asset)
        }
        mediaStore.deleteWardrobeMedia(itemID: item.id)
        modelContext.delete(item)
        try modelContext.save()
    }
}
