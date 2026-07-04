import PhotosUI
import SwiftUI
import UIKit

/// Shared capture/import rows for the add-item and replace-photo sheets:
/// camera and photo-library buttons, extraction progress, the cutout
/// preview, and the use-cutout toggle. Hosts embed it in their own Form
/// section; all photo state flows through the passed-in selection model.
struct WardrobePhotoPicker: View {
    @Bindable var photoSelection: WardrobePhotoSelection

    @State private var pickerItem: PhotosPickerItem?
    @State private var showingCamera = false

    var body: some View {
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
            Toggle("Use background-removed cutout", isOn: $photoSelection.useExtracted)
        } else if photoSelection.extractionFailed {
            Text("The item couldn't be separated from its background, so the full photo will be used. A plain, contrasting background helps.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
