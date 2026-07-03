import SwiftUI

/// Adaptive shell: bottom tabs on compact iPhone, sidebar on iPad and wide widths.
/// The unsaved try-on composition lives here so switching tabs does not lose it.
struct MainShellView: View {
    @State private var composition = TryOnComposition()

    var body: some View {
        TabView {
            Tab("Try On", systemImage: "person.crop.rectangle") {
                TryOnStudioView(composition: composition)
            }

            Tab("Closet", systemImage: "tshirt") {
                ClosetView()
            }

            Tab("Lookbook", systemImage: "rectangle.grid.2x2") {
                LookbookView()
            }

            Tab("Avatar", systemImage: "person.crop.circle") {
                AvatarView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}
