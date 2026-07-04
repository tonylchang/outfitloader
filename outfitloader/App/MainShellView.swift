import SwiftUI

/// Adaptive shell: bottom tabs on compact iPhone, sidebar on iPad and wide widths.
/// The unsaved try-on composition lives here so switching tabs does not lose it.
struct MainShellView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.mediaStore) private var mediaStore

    @State private var composition = TryOnComposition()
    @State private var selectedTab: MainTab = .tryOn
    @State private var reopenErrorMessage: String?

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Try On", systemImage: "person.crop.rectangle", value: .tryOn) {
                TryOnStudioView(composition: composition) {
                    selectedTab = .closet
                }
            }

            Tab("Closet", systemImage: "tshirt", value: .closet) {
                ClosetView()
            }

            Tab("Lookbook", systemImage: "rectangle.grid.2x2", value: .lookbook) {
                LookbookView(
                    onReopenLook: { look in
                        reopenLook(look)
                    },
                    onOpenTryOn: {
                        selectedTab = .tryOn
                    }
                )
            }

            Tab("Avatar", systemImage: "person.crop.circle", value: .avatar) {
                AvatarView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .errorAlert("Couldn't Reopen Look", message: $reopenErrorMessage)
    }

    private func reopenLook(_ look: OutfitLook) {
        Task { @MainActor in
            do {
                let repository = LookRepository(modelContext: modelContext, mediaStore: mediaStore)
                let hydrated = try await repository.hydrateComposition(from: look)
                composition.loadSavedLook(
                    avatarAdjustment: hydrated.avatarAdjustment,
                    layers: hydrated.layers
                )
                selectedTab = .tryOn
            } catch {
                reopenErrorMessage = error.localizedDescription
            }
        }
    }
}

private enum MainTab: Hashable {
    case tryOn
    case closet
    case lookbook
    case avatar
}
