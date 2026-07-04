import SwiftData
import SwiftUI

@main
struct OutfitloaderApp: App {
    /// nil only when even the in-memory fallback container failed; the app
    /// then shows a SwiftData-free error screen instead of terminating.
    private let modelContainer: ModelContainer?
    private let startupErrorDescription: String?

    init() {
        do {
            modelContainer = try ModelContainerFactory.makeDefault()
            startupErrorDescription = nil
        } catch {
            startupErrorDescription = error.localizedDescription
            modelContainer = try? ModelContainerFactory.makeInMemory()
        }
    }

    var body: some Scene {
        WindowGroup {
            if let modelContainer {
                Group {
                    if let startupErrorDescription {
                        StoreUnavailableView(errorDescription: startupErrorDescription, isTerminal: false)
                    } else {
                        AppRootView()
                    }
                }
                .modelContainer(modelContainer)
            } else {
                StoreUnavailableView(
                    errorDescription: startupErrorDescription ?? "The local data store could not be created.",
                    isTerminal: true
                )
            }
        }
    }
}

private struct StoreUnavailableView: View {
    let errorDescription: String
    let isTerminal: Bool

    var body: some View {
        ContentUnavailableView {
            Label("Local Store Unavailable", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text(isTerminal
                ? "outfitloader could not open its local data store, even temporarily. Free up storage space or restart your device, then reopen the app. If this keeps happening, reinstalling the app will reset local data."
                : "outfitloader could not open its local data store. Restart the app. If this keeps happening, reinstalling the app will reset local data.")
        } actions: {
            Text(errorDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
