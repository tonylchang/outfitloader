import SwiftData
import SwiftUI
import UIKit

/// Replaces an existing item's image assets while preserving the item record,
/// category, and saved-look references.
struct ReplaceWardrobePhotoSheet: View {
    @Bindable var item: WardrobeItem

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.mediaStore) private var mediaStore

    @State private var photoSelection = WardrobePhotoSelection()
    @State private var isReplacing = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Current Photo") {
                    MediaImageView(asset: item.thumbnailImage, fallback: item.displayImage, placeholderSymbol: "tshirt")
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }

                Section {
                    WardrobePhotoPicker(photoSelection: photoSelection)

                    if isReplacing {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Updating the closet item…")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("New Photo")
                } footer: {
                    Text("The item's name and category will stay the same.")
                }
            }
            .navigationTitle("Replace Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isReplacing)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Replace") {
                        replacePhoto()
                    }
                    .disabled(photoSelection.originalImage == nil || photoSelection.isExtracting || isReplacing)
                }
            }
            .errorAlert("Couldn't Replace Photo", message: $photoSelection.errorMessage)
        }
    }

    @MainActor
    private func replacePhoto() {
        guard let originalImage = photoSelection.originalImage else {
            return
        }

        isReplacing = true
        Task { @MainActor in
            do {
                let wardrobeRepository = WardrobeRepository(modelContext: modelContext, mediaStore: mediaStore)
                try await wardrobeRepository.replaceItemPhoto(
                    item,
                    originalImage: originalImage,
                    processedImage: photoSelection.processedImageForSave,
                    capturedFrom: photoSelection.imageSource
                )

                let lookRepository = LookRepository(modelContext: modelContext, mediaStore: mediaStore)
                await lookRepository.refreshPreviews(containing: item)

                dismiss()
            } catch {
                photoSelection.errorMessage = error.localizedDescription
            }

            isReplacing = false
        }
    }
}
