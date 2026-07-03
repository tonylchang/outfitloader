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
    @State private var originalImage: UIImage?
    @State private var extractedImage: UIImage?
    @State private var useExtracted = true
    @State private var isExtracting = false
    @State private var isReplacing = false
    @State private var extractionFailed = false
    @State private var imageSource: ImageSource = .photoLibrary
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Current Photo") {
                    MediaImageView(asset: item.displayImage, placeholderSymbol: "tshirt")
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
                    .disabled(originalImage == nil || isExtracting || isReplacing)
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                GuidedCameraSheet(
                    mode: .clothing,
                    title: "Clothing Capture",
                    guidance: "Place one item flat in frame with as plain a background as possible."
                ) { image in
                    handleImage(image, from: .camera)
                }
            }
            .onChange(of: pickerItem) { _, newItem in
                Task {
                    await loadPickedImage(newItem)
                }
            }
            .alert(
                "Couldn't Replace Photo",
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

            if isExtracting {
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

            if let preview = previewImage {
                HStack {
                    Spacer()
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                    Spacer()
                }
            }

            if extractedImage != nil {
                Toggle("Use background-removed cutout", isOn: $useExtracted)
            } else if extractionFailed {
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

    private var previewImage: UIImage? {
        if let extractedImage, useExtracted {
            return extractedImage
        }

        return originalImage
    }

    @MainActor
    private func loadPickedImage(_ item: PhotosPickerItem?) async {
        guard let item else {
            return
        }

        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data)
        else {
            errorMessage = "That photo couldn't be loaded. Try a different one."
            return
        }

        handleImage(image, from: .photoLibrary)
    }

    @MainActor
    private func handleImage(_ image: UIImage, from source: ImageSource) {
        let resized = image.resizedToFit(maxPixelSize: 1600)
        originalImage = resized
        extractedImage = nil
        extractionFailed = false
        useExtracted = true
        imageSource = source
        isExtracting = true

        Task {
            await extractForeground(from: resized)
        }
    }

    @MainActor
    private func extractForeground(from image: UIImage) async {
        do {
            let foreground = try await Task.detached(priority: .userInitiated) {
                try ClothingForegroundExtractor().extractForeground(from: image)
            }.value

            extractedImage = foreground
        } catch {
            extractedImage = nil
            extractionFailed = true
        }

        isExtracting = false
    }

    @MainActor
    private func replacePhoto() {
        guard let originalImage else {
            return
        }

        isReplacing = true
        Task { @MainActor in
            do {
                let wardrobeRepository = WardrobeRepository(modelContext: modelContext, mediaStore: mediaStore)
                try wardrobeRepository.replaceItemPhoto(
                    item,
                    originalImage: originalImage,
                    processedImage: useExtracted ? extractedImage : nil,
                    capturedFrom: imageSource
                )

                let lookRepository = LookRepository(modelContext: modelContext, mediaStore: mediaStore)
                await lookRepository.refreshPreviews(containing: item)

                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }

            isReplacing = false
        }
    }
}
