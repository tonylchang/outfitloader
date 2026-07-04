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

    @State private var photoSelection = WardrobePhotoSelection()
    @State private var name = ""
    @State private var selectedKind: CategoryKind = .tops
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Photo") {
                    WardrobePhotoPicker(photoSelection: photoSelection)
                }

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
                    .disabled(photoSelection.originalImage == nil || photoSelection.isExtracting || isSaving)
                }
            }
            .errorAlert("Couldn't Save Item", message: $photoSelection.errorMessage)
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

    @MainActor
    private func save() {
        guard let originalImage = photoSelection.originalImage else {
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        isSaving = true
        Task {
            do {
                let repository = WardrobeRepository(modelContext: modelContext, mediaStore: mediaStore)
                try await repository.createItem(
                    named: trimmedName.isEmpty ? selectedKind.newItemName : trimmedName,
                    kind: selectedKind,
                    originalImage: originalImage,
                    processedImage: photoSelection.processedImageForSave,
                    capturedFrom: photoSelection.imageSource
                )
                dismiss()
            } catch {
                photoSelection.errorMessage = error.localizedDescription
            }

            isSaving = false
        }
    }
}
