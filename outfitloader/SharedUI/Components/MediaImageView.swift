import SwiftUI
import UIKit

/// Loads an ImageAsset's file off the main thread and renders it with a
/// neutral placeholder while loading or when the asset is missing.
struct MediaImageView: View {
    let asset: ImageAsset?
    var contentMode: ContentMode = .fit
    var placeholderSymbol: String = "photo"

    @Environment(\.mediaStore) private var mediaStore
    @State private var loadedImage: UIImage?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.secondary.opacity(0.08))

            if let loadedImage {
                Image(uiImage: loadedImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Image(systemName: placeholderSymbol)
                    .font(.title3)
                    .foregroundStyle(.tertiary)
            }
        }
        .task(id: asset?.relativePath) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let asset else {
            loadedImage = nil
            return
        }

        let store = mediaStore
        let relativePath = asset.relativePath
        let kindRawValue = asset.kindRawValue
        loadedImage = await Task.detached(priority: .userInitiated) {
            store.loadImage(relativePath: relativePath, kindRawValue: kindRawValue)
        }.value
    }
}
