import SwiftData
import SwiftUI

/// Decides between first-run onboarding and the main app shell based on
/// whether an active avatar exists in SwiftData (not user defaults).
struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<AvatarProfile> { $0.isActive })
    private var activeAvatars: [AvatarProfile]

    var body: some View {
        Group {
            if activeAvatars.isEmpty {
                AvatarOnboardingView()
            } else {
                MainShellView()
            }
        }
        .task {
            do {
                try SeedData.seedDefaultCategories(in: modelContext)
            } catch {
                assertionFailure("Category seeding failed: \(error)")
            }
        }
    }
}
