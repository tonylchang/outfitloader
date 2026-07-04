import Foundation
import SwiftData

/// Deletes user-owned local data while preserving system seed data such as
/// closet categories. Media files are removed only after SwiftData saves.
@MainActor
struct LocalDataRepository {
    let modelContext: ModelContext
    let mediaStore: MediaStore

    func deleteAllUserData() async throws {
        let looks = try modelContext.fetch(FetchDescriptor<OutfitLook>())
        let items = try modelContext.fetch(FetchDescriptor<WardrobeItem>())
        let avatars = try modelContext.fetch(FetchDescriptor<AvatarProfile>())

        for look in looks {
            modelContext.delete(look)
        }

        for item in items {
            modelContext.delete(item)
        }

        for avatar in avatars {
            modelContext.delete(avatar)
        }

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }

        await mediaStore.deleteAllMedia()
    }
}
