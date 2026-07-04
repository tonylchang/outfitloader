import OSLog
import SwiftData
import SwiftUI

/// Decides between first-run onboarding and the main app shell based on
/// whether an active avatar exists in SwiftData (not user defaults).
struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.mediaStore) private var mediaStore
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

            await runDebugOrphanScan()
        }
    }

    /// Development-only integrity check; counts only, never paths.
    private func runDebugOrphanScan() async {
        #if DEBUG
        let logger = Logger(subsystem: "net.1x0.outfitloader", category: "media-integrity")
        do {
            let scanner = MediaOrphanScanner(modelContext: modelContext, mediaStore: mediaStore)
            let report = try await scanner.scan()
            if report.hasFindings {
                logger.warning("""
                Orphan scan found problems: rows with missing files \
                \(String(describing: report.missingFilesByKind), privacy: .public), \
                unreferenced durable files \(report.orphanedDurableFileCount), \
                unreferenced cached files \(report.orphanedCachedFileCount)
                """)
            } else {
                logger.debug("Orphan scan clean")
            }
        } catch {
            logger.error("Orphan scan failed: \(error.localizedDescription, privacy: .public)")
        }
        #endif
    }
}
