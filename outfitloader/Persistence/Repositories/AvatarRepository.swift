import Foundation
import SwiftData
import UIKit

/// Owns the transaction that keeps avatar SwiftData rows and media files consistent:
/// files are written before rows are inserted, and orphaned files are cleaned up
/// when a save fails.
@MainActor
struct AvatarRepository {
    let modelContext: ModelContext
    let mediaStore: MediaStore

    @discardableResult
    func createAvatar(
        sourceImage: UIImage,
        silhouetteImage: UIImage?,
        capturedFrom source: ImageSource,
        displayName: String? = nil
    ) throws -> AvatarProfile {
        let avatarID = UUID()

        let originalDraft: ImageAssetDraft
        var silhouetteDraft: ImageAssetDraft?
        do {
            originalDraft = try mediaStore.writeAvatarOriginal(sourceImage, avatarID: avatarID, source: source)
            if let silhouetteImage {
                silhouetteDraft = try mediaStore.writeAvatarSilhouette(silhouetteImage, avatarID: avatarID)
            }
        } catch {
            mediaStore.deleteAvatarMedia(avatarID: avatarID)
            throw error
        }

        let previouslyActive = try modelContext.fetch(
            FetchDescriptor<AvatarProfile>(predicate: #Predicate { $0.isActive })
        )
        for profile in previouslyActive {
            profile.isActive = false
            profile.updatedAt = .now
        }

        let profile = AvatarProfile(
            id: avatarID,
            displayName: displayName,
            isActive: true,
            processingStatus: silhouetteDraft == nil ? .failed : .ready
        )
        profile.sourceImage = ImageAsset(draft: originalDraft)
        profile.silhouetteImage = silhouetteDraft.map { ImageAsset(draft: $0) }
        modelContext.insert(profile)

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            mediaStore.deleteAvatarMedia(avatarID: avatarID)
            throw error
        }

        return profile
    }

    func deleteAvatar(_ profile: AvatarProfile) throws {
        mediaStore.deleteAvatarMedia(avatarID: profile.id)
        modelContext.delete(profile)
        try modelContext.save()
    }
}
