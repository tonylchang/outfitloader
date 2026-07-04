import SwiftUI
import UIKit

/// Loads an ImageAsset's file off the main thread and renders it with a
/// neutral placeholder while loading or when the asset is missing.
///
/// When a `fallback` asset is provided it stands in for a nil or unloadable
/// primary asset; a purged cache-stored thumbnail is regenerated in place
/// from the fallback so the closet grid recovers from system cache eviction.
struct MediaImageView: View {
    let asset: ImageAsset?
    var fallback: ImageAsset? = nil
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
        .task(id: reloadKey) {
            await loadImage()
        }
    }

    /// Reload when the path changes or when the file is rewritten in place:
    /// look-preview refreshes reuse `Outfits/<id>/preview.jpg` and bump the
    /// row's `updatedAt`, so the path alone would never retrigger the task.
    private var reloadKey: String {
        guard let active = asset ?? fallback else {
            return "none"
        }

        return "\(active.relativePath)|\(active.updatedAt.timeIntervalSinceReferenceDate)"
    }

    private func loadImage() async {
        guard let asset else {
            loadedImage = await load(fallback)
            return
        }

        if let image = await load(asset) {
            loadedImage = image
            return
        }

        guard let fallback else {
            loadedImage = nil
            return
        }

        if asset.kind?.isCacheStored == true {
            loadedImage = await mediaStore.regenerateThumbnail(
                relativePath: asset.relativePath,
                fromSourcePath: fallback.relativePath,
                sourceKindRawValue: fallback.kindRawValue
            )
        } else {
            loadedImage = await load(fallback)
        }
    }

    private func load(_ asset: ImageAsset?) async -> UIImage? {
        guard let asset else {
            return nil
        }

        return await mediaStore.loadImage(
            relativePath: asset.relativePath,
            kindRawValue: asset.kindRawValue
        )
    }
}
