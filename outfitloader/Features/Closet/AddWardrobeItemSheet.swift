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
    @State private var photoSelection = WardrobePhotoSelection()
    @State private var name = ""
    @State private var selectedKind: CategoryKind = .tops

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
                    .disabled(photoSelection.originalImage == nil || photoSelection.isExtracting)
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                GuidedCameraSheet(
                    mode: .clothing,
                    title: "Clothing Capture",
                    guidance: "Place one item flat in frame with as plain a background as possible."
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
                "Couldn't Save Item",
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

            if photoSelection.isExtracting {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Removing the background on device…")
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

    private var useExtractedBinding: Binding<Bool> {
        Binding {
            photoSelection.useExtracted
        } set: { newValue in
            photoSelection.useExtracted = newValue
        }
    }

    @MainActor
    private func save() {
        guard let originalImage = photoSelection.originalImage else {
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
                processedImage: photoSelection.processedImageForSave,
                capturedFrom: photoSelection.imageSource
            )
            dismiss()
        } catch {
            photoSelection.errorMessage = error.localizedDescription
        }
    }
}
