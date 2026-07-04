import SwiftData
import SwiftUI
import UIKit

/// Try-on studio: the avatar canvas with a wardrobe shelf. Tapping a shelf
/// item places it on the avatar (replacing any item in the same category);
/// tapping a placed item removes it.
struct TryOnStudioView: View {
    @Bindable var composition: TryOnComposition
    var onOpenCloset: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
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
    @State private var showingSaveSheet = false

    private var activeAvatar: AvatarProfile? {
        activeAvatars.first
    }

    private var avatarDisplayAsset: ImageAsset? {
        guard let avatar = activeAvatar else {
            return nil
        }

        return avatar.silhouetteImage ?? avatar.sourceImage
    }

    private var avatarRenderKey: String {
        [
            avatarDisplayAsset?.relativePath ?? "none",
            activeAvatar?.bodyShapeAdjustment.cacheKey ?? AvatarBodyShapeAdjustment.neutral.cacheKey
        ].joined(separator: "|")
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
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Save", systemImage: "square.and.arrow.down") {
                        showingSaveSheet = true
                    }
                    .disabled(!composition.canSave || avatarImage == nil || activeAvatar == nil)

                    Button("Reset", systemImage: "arrow.counterclockwise") {
                        composition.reset()
                    }
                    .disabled(composition.isPristine)
                }
            }
            .task(id: avatarRenderKey) {
                await loadAvatarImage()
            }
            .sheet(isPresented: $showingSaveSheet) {
                SaveLookSheet(defaultName: defaultLookName) { name in
                    try await saveLook(named: name)
                }
            }
        }
    }

    private var defaultLookName: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "Look \(formatter.string(from: .now))"
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
                VStack(spacing: 6) {
                    Text(items.isEmpty
                        ? "Your closet is empty."
                        : "No items in \(shelfFilter.title).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if items.isEmpty {
                        Button("Add clothes in Closet", action: onOpenCloset)
                            .font(.footnote.weight(.semibold))
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
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
        guard let avatar = activeAvatar, let asset = avatarDisplayAsset else {
            avatarImage = nil
            return
        }

        let adjustment = avatar.bodyShapeAdjustment
        guard let source = await mediaStore.loadImage(
            relativePath: asset.relativePath,
            kindRawValue: asset.kindRawValue
        ) else {
            avatarImage = nil
            return
        }

        avatarImage = await Task.detached(priority: .userInitiated) {
            AvatarBodyShapeRenderer().render(source, adjustment: adjustment)
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

        let relativePath = asset.relativePath
        let kindRawValue = asset.kindRawValue
        let itemID = item.id
        let itemName = item.name
        let kind = item.categoryKind ?? .tops

        Task {
            guard let image = await mediaStore.loadImage(
                relativePath: relativePath,
                kindRawValue: kindRawValue
            ) else {
                return
            }

            composition.place(itemID: itemID, name: itemName, kind: kind, image: image)
        }
    }

    private func saveLook(named name: String) async throws {
        guard let avatar = activeAvatar, let avatarImage else {
            throw LookRepositoryError.missingAvatar
        }

        let repository = LookRepository(modelContext: modelContext, mediaStore: mediaStore)
        try await repository.createLook(
            named: name,
            avatar: avatar,
            avatarImage: avatarImage,
            composition: composition,
            wardrobeItems: items
        )
    }
}

private struct SaveLookSheet: View {
    let defaultName: String
    let onSave: (String) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(defaultName: String, onSave: @escaping (String) async throws -> Void) {
        self.defaultName = defaultName
        self.onSave = onSave
        _name = State(initialValue: defaultName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Look name", text: $name)
                        .textInputAutocapitalization(.words)
                }
            }
            .navigationTitle("Save Look")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .alert(
                "Couldn't Save Look",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func save() {
        isSaving = true
        Task {
            do {
                try await onSave(name)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }

            isSaving = false
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
