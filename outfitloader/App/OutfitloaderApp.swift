import SwiftData
import SwiftUI

@main
struct OutfitloaderApp: App {
    private let modelContainer: ModelContainer
    private let startupErrorDescription: String?

    init() {
        do {
            modelContainer = try ModelContainerFactory.makeDefault()
            startupErrorDescription = nil
        } catch {
            startupErrorDescription = error.localizedDescription
            do {
                modelContainer = try ModelContainerFactory.makeInMemory()
            } catch {
                fatalError("Could not create a fallback SwiftData store: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            if let startupErrorDescription {
                StoreUnavailableView(errorDescription: startupErrorDescription)
            } else {
                AppRootView()
            }
        }
        .modelContainer(modelContainer)
    }
}

private struct StoreUnavailableView: View {
    let errorDescription: String

    var body: some View {
        ContentUnavailableView {
            Label("Local Store Unavailable", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("outfitloader could not open its local data store. Restart the app. If this keeps happening, reinstalling the app will reset local data.")
        } actions: {
            Text(errorDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
