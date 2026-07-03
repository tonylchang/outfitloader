import SwiftData
import SwiftUI
import UIKit

/// Try-on studio: the avatar canvas with a wardrobe shelf. Tapping a shelf
/// item places it on the avatar (replacing any item in the same category);
/// tapping a placed item removes it.
struct TryOnStudioView: View {
    @Bindable var composition: TryOnComposition

    @Environment(\.mediaStore) private var mediaStore
    @Query(filter: #Predicate<AvatarProfile> { $0.isActive })
    private var activeAvatars: [AvatarProfile]
    @Query(
        filter: #Predicate<WardrobeItem> { $0.isArchived == false },
        sort: \WardrobeItem.createdAt,
        order: .reverse
    )
    private var items: [WardrobeItem]

    @State private var avatarImage: UIImage?
    @State private var shelfFilter: CategoryFilter = .all

    private var avatarDisplayAsset: ImageAsset? {
        guard let avatar = activeAvatars.first else {
            return nil
        }

        return avatar.silhouetteImage ?? avatar.sourceImage
    }

    private var shelfItems: [WardrobeItem] {
        items.filter { shelfFilter.matches($0) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                TryOnCanvasView(avatarImage: avatarImage, composition: composition)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .layoutPriority(1)

                TryOnControlsView(composition: composition)

                Divider()

                shelf
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            .navigationTitle("Try On")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Reset", systemImage: "arrow.counterclockwise") {
                        composition.reset()
                    }
                    .disabled(composition.isPristine)
                }
            }
            .task(id: avatarDisplayAsset?.relativePath) {
                await loadAvatarImage()
            }
        }
    }

    private var shelf: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Closet")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                CategoryFilterPicker(filter: $shelfFilter)
                    .controlSize(.small)
            }

            if shelfItems.isEmpty {
                Text(items.isEmpty
                    ? "Add clothes in the Closet tab to try them on."
                    : "No items in \(shelfFilter.title).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(shelfItems) { item in
                            ShelfItemButton(
                                item: item,
                                isPlaced: composition.isPlaced(itemID: item.id)
                            ) {
                                toggleItem(item)
                            }
                        }
                    }
                }
                .frame(height: 82)
            }
        }
    }

    @MainActor
    private func loadAvatarImage() async {
        guard let asset = avatarDisplayAsset else {
            avatarImage = nil
            return
        }

        let store = mediaStore
        let relativePath = asset.relativePath
        let kindRawValue = asset.kindRawValue
        avatarImage = await Task.detached(priority: .userInitiated) {
            store.loadImage(relativePath: relativePath, kindRawValue: kindRawValue)
        }.value
    }

    @MainActor
    private func toggleItem(_ item: WardrobeItem) {
        if composition.isPlaced(itemID: item.id) {
            composition.remove(itemID: item.id)
            return
        }

        guard let asset = item.displayImage else {
            return
        }

        let store = mediaStore
        let relativePath = asset.relativePath
        let kindRawValue = asset.kindRawValue
        let itemID = item.id
        let itemName = item.name
        let kind = item.categoryKind ?? .tops

        Task {
            guard let image = await Task.detached(priority: .userInitiated, operation: {
                store.loadImage(relativePath: relativePath, kindRawValue: kindRawValue)
            }).value else {
                return
            }

            composition.place(itemID: itemID, name: itemName, kind: kind, image: image)
        }
    }
}

private struct ShelfItemButton: View {
    let item: WardrobeItem
    let isPlaced: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                MediaImageView(
                    asset: item.thumbnailImage ?? item.displayImage,
                    placeholderSymbol: "tshirt"
                )
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if isPlaced {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.accentColor)
                            .padding(2)
                    }
                }

                Text(item.name)
                    .font(.caption2)
                    .lineLimit(1)
                    .frame(width: 68)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isPlaced ? "Remove \(item.name)" : "Try on \(item.name)")
    }
}
