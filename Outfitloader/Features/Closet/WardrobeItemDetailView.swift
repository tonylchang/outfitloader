import SwiftData
import SwiftUI

struct WardrobeItemDetailView: View {
    @Bindable var item: WardrobeItem

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.mediaStore) private var mediaStore
    @Query(sort: \ClosetCategory.sortIndex) private var categories: [ClosetCategory]

    @State private var showingDeleteConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                MediaImageView(asset: item.displayImage, placeholderSymbol: "tshirt")
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
                Button("Delete Item", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            } footer: {
                Text("Deleting removes the item and its photos from this device.")
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: item.name) {
            item.updatedAt = .now
        }
        .confirmationDialog(
            "Delete \(item.name)?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteItem()
            }
        } message: {
            Text("The item and its photos will be removed from this device.")
        }
        .alert(
            "Couldn't Delete Item",
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
        do {
            let repository = WardrobeRepository(modelContext: modelContext, mediaStore: mediaStore)
            try repository.deleteItem(item)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
