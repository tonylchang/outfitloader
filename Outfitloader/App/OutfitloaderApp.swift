import SwiftData
import SwiftUI

@main
struct OutfitloaderApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainerFactory.makeDefault()
        } catch {
            fatalError("Could not create the local SwiftData store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(modelContainer)
    }
}
