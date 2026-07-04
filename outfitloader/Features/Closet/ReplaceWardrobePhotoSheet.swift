import PhotosUI
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

    @State private var pickerItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var photoSelection = WardrobePhotoSelection()
    @State private var isReplacing = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Current Photo") {
                    MediaImageView(asset: item.thumbnailImage ?? item.displayImage, placeholderSymbol: "tshirt")
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }

                replacementPhotoSection
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
            .fullScreenCover(isPresented: $showingCamera) {
                GuidedCameraSheet(
                    mode: .clothing,
                    title: "Clothing Capture",
                    guidance: "Lay one item flat on a plain, contrasting surface. Bright, even light with no shadows makes a cleaner cutout."
                ) { image in
                    photoSelection.handleImage(image, from: .camera)
                }
            }
            .onChange(of: pickerItem) { _, newItem in
                Task {
                    await photoSelection.loadPickedImage(newItem)
                }
            }
            .alert(
                "Couldn't Replace Photo",
                isPresented: Binding(
                    get: { photoSelection.errorMessage != nil },
                    set: { if !$0 { photoSelection.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(photoSelection.errorMessage ?? "")
            }
        }
    }

    private var replacementPhotoSection: some View {
        Section {
            HStack(spacing: 12) {
                Button {
                    showingCamera = true
                } label: {
                    Label("Camera", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Import", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            if photoSelection.isExtracting {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Removing the background on device...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if isReplacing {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Updating the closet item...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let preview = photoSelection.previewImage {
                HStack {
                    Spacer()
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                    Spacer()
                }
            }

            if photoSelection.extractedImage != nil {
                Toggle("Use background-removed cutout", isOn: useExtractedBinding)
            } else if photoSelection.extractionFailed {
                Text("The item couldn't be separated from its background, so the full photo will be used. A plain, contrasting background helps.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("New Photo")
        } footer: {
            Text("The item's name and category will stay the same.")
        }
    }

    private var useExtractedBinding: Binding<Bool> {
        Binding {
            photoSelection.useExtracted
        } set: { newValue in
            photoSelection.useExtracted = newValue
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
