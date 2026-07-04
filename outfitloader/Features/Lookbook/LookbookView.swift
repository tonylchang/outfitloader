import SwiftData
import SwiftUI

struct LookbookView: View {
    let onReopenLook: (OutfitLook) -> Void

    @Query(
        filter: #Predicate<OutfitLook> { $0.isArchived == false },
        sort: \OutfitLook.createdAt,
        order: .reverse
    )
    private var looks: [OutfitLook]

    var body: some View {
        NavigationStack {
            Group {
                if looks.isEmpty {
                    ContentUnavailableView {
                        Label("No Looks Yet", systemImage: "rectangle.grid.2x2")
                    } description: {
                        Text("Assemble and save an outfit in Try On.")
                    }
                } else {
                    lookGrid
                }
            }
            .navigationTitle("Lookbook")
            .navigationDestination(for: OutfitLook.self) { look in
                LookbookDetailView(look: look, onReopenLook: onReopenLook)
            }
        }
    }

    private var lookGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 12)],
                spacing: 12
            ) {
                ForEach(looks) { look in
                    NavigationLink(value: look) {
                        VStack(alignment: .leading, spacing: 6) {
                            MediaImageView(asset: look.previewImage, placeholderSymbol: "rectangle.grid.2x2")
                                .frame(height: 180)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            Text(look.name)
                                .font(.footnote.weight(.medium))
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
}

private struct LookbookDetailView: View {
    @Bindable var look: OutfitLook
    let onReopenLook: (OutfitLook) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.mediaStore) private var mediaStore
    @State private var showingDeleteConfirmation = false
    @State private var errorMessage: String?

    private var sortedSlots: [OutfitSlot] {
        look.slots.sorted { $0.zIndex < $1.zIndex }
    }

    var body: some View {
        List {
            Section {
                MediaImageView(asset: look.previewImage, placeholderSymbol: "rectangle.grid.2x2")
                    .frame(maxWidth: .infinity)
                    .frame(height: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            Section("Details") {
                TextField("Name", text: $look.name)

                LabeledContent("Items") {
                    Text("\(sortedSlots.count)")
                }
            }

            Section("Items") {
                ForEach(sortedSlots) { slot in
                    LookSlotRow(slot: slot)
                }
            }

            Section {
                Button("Reopen in Try On", systemImage: "arrow.uturn.left") {
                    onReopenLook(look)
                }

                Button("Delete Look", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            }
        }
        .navigationTitle(look.name)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: look.name) {
            look.updatedAt = .now
            try? modelContext.save()
        }
        .confirmationDialog(
            "Delete \(look.name)?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteLook()
            }
        } message: {
            Text("The saved look and its preview will be removed from this device. Closet items will stay in your closet.")
        }
        .alert(
            "Couldn't Delete Look",
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

    private func deleteLook() {
        Task {
            do {
                let repository = LookRepository(modelContext: modelContext, mediaStore: mediaStore)
                try await repository.deleteLook(look)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct LookSlotRow: View {
    let slot: OutfitSlot

    private var item: WardrobeItem? {
        slot.wardrobeItem
    }

    var body: some View {
        HStack(spacing: 12) {
            MediaImageView(asset: item?.thumbnailImage ?? item?.displayImage, placeholderSymbol: slot.categoryKind?.symbolName ?? "tshirt")
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(item?.name ?? "Missing Item")
                    .font(.subheadline.weight(.medium))

                Text(slot.categoryKind?.displayName ?? item?.categoryKind?.displayName ?? "Clothing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}
