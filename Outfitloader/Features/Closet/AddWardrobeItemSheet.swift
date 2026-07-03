import PhotosUI
import SwiftData
import SwiftUI
import UIKit

/// Add-item flow: capture or import a clothing photo, attempt native Vision
/// foreground extraction on device, and save the item with a transparent
/// cutout when extraction succeeds.
struct AddWardrobeItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.mediaStore) private var mediaStore
    @Query(sort: \ClosetCategory.sortIndex) private var categories: [ClosetCategory]

    @State private var pickerItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var originalImage: UIImage?
    @State private var extractedImage: UIImage?
    @State private var useExtracted = true
    @State private var isExtracting = false
    @State private var extractionFailed = false
    @State private var name = ""
    @State private var selectedKind: CategoryKind = .tops
    @State private var imageSource: ImageSource = .photoLibrary
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                photoSection
                detailsSection
            }
            .navigationTitle("Add Item")
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
                    .disabled(originalImage == nil || isExtracting)
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
                "Couldn't Save Item",
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

    private var photoSection: some View {
        Section("Photo") {
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
                    Text("Removing the background on device…")
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
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            TextField("Name", text: $name, prompt: Text(selectedKind.newItemName))

            Picker("Category", selection: $selectedKind) {
                ForEach(CategoryKind.allCases) { kind in
                    Label(kind.displayName, systemImage: kind.symbolName)
                        .tag(kind)
                }
            }
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
    private func save() {
        guard let originalImage else {
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = categories.first { $0.kindRawValue == selectedKind.rawValue }

        do {
            let repository = WardrobeRepository(modelContext: modelContext, mediaStore: mediaStore)
            try repository.createItem(
                named: trimmedName.isEmpty ? selectedKind.newItemName : trimmedName,
                kind: selectedKind,
                category: category,
                originalImage: originalImage,
                processedImage: useExtracted ? extractedImage : nil,
                capturedFrom: imageSource
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
