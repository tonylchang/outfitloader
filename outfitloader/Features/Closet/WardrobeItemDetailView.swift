import SwiftData
import SwiftUI

struct WardrobeItemDetailView: View {
    @Bindable var item: WardrobeItem

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.mediaStore) private var mediaStore
    @Query(sort: \ClosetCategory.sortIndex) private var categories: [ClosetCategory]
    @Query(
        filter: #Predicate<OutfitLook> { $0.isArchived == false },
        sort: \OutfitLook.createdAt,
        order: .reverse
    )
    private var looks: [OutfitLook]

    @State private var showingDeleteConfirmation = false
    @State private var showingReplacePhotoSheet = false
    @State private var errorMessage: String?

    private var usageCount: Int {
        looks.filter { look in
            look.slots.contains { $0.wardrobeItem?.id == item.id }
        }.count
    }

    var body: some View {
        Form {
            Section {
                MediaImageView(asset: item.thumbnailImage, fallback: item.displayImage, placeholderSymbol: "tshirt")
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            Section("Details") {
                TextField("Name", text: $item.name)

                Picker("Category", selection: kindBinding) {
                    ForEach(CategoryKind.allCases) { kind in
                        Label(kind.displayName, systemImage: kind.symbolName)
                            .tag(kind)
                    }
                }
            }

            Section {
                Button("Replace Photo", systemImage: "photo.badge.arrow.down") {
                    showingReplacePhotoSheet = true
                }
            } footer: {
                Text("Replacing updates the closet item photo stored on this device.")
            }

            Section {
                Button("Delete Item", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            } footer: {
                if usageCount > 0 {
                    Text("This item is used in \(usageCount) saved \(usageCount == 1 ? "look" : "looks"). Delete those looks before deleting this item.")
                } else {
                    Text("Deleting removes the item and its photos from this device.")
                }
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: item.name) {
            item.updatedAt = .now
        }
        .sheet(isPresented: $showingReplacePhotoSheet) {
            ReplaceWardrobePhotoSheet(item: item)
        }
        .confirmationDialog(
            "Delete \(item.name)?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            if usageCount == 0 {
                Button("Delete", role: .destructive) {
                    deleteItem()
                }
            } else {
                Button("OK", role: .cancel) {}
            }
        } message: {
            if usageCount > 0 {
                Text("This item is used in \(usageCount) saved \(usageCount == 1 ? "look" : "looks"). Delete those looks before deleting this item.")
            } else {
                Text("The item and its photos will be removed from this device.")
            }
        }
        .errorAlert("Couldn't Delete Item", message: $errorMessage)
    }

    private var kindBinding: Binding<CategoryKind> {
        Binding {
            item.categoryKind ?? .tops
        } set: { newKind in
            item.categoryKindRawValue = newKind.rawValue
            item.category = categories.first { $0.kindRawValue == newKind.rawValue }
            item.updatedAt = .now
        }
    }

    private func deleteItem() {
        Task {
            do {
                let repository = WardrobeRepository(modelContext: modelContext, mediaStore: mediaStore)
                try await repository.deleteItem(item)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
