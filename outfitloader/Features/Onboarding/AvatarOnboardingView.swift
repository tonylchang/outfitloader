import PhotosUI
import SwiftUI
import UIKit

/// First-run flow: guided full-body selfie capture or camera-roll import,
/// on-device silhouette generation, then explicit confirmation before the
/// avatar is saved locally.
struct AvatarOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.mediaStore) private var mediaStore

    @State private var pickerItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var sourceImage: UIImage?
    @State private var silhouetteImage: UIImage?
    @State private var imageSource: ImageSource = .photoLibrary
    @State private var isProcessing = false
    @State private var isSaving = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header

                    if let sourceImage {
                        previewSection(sourceImage)
                    } else {
                        captureButtons
                    }
                }
                .padding()
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Create Your Avatar")
            .fullScreenCover(isPresented: $showingCamera) {
                GuidedCameraSheet(
                    mode: .avatarSelfie,
                    title: "Selfie Capture",
                    guidance: "Stand facing the camera with your full body inside the guide. Even light and a simple background give the best silhouette."
                ) { image in
                    handleImage(image, from: .camera)
                }
            }
            .onChange(of: pickerItem) { _, newItem in
                Task {
                    await loadPickedImage(newItem)
                }
            }
            .errorAlert("Couldn't Save Avatar", message: $errorMessage)
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.rectangle.badge.plus")
                .font(.system(size: 44))
                .foregroundStyle(.tint)

            Text("outfitloader builds a try-on avatar from one full-body selfie. Your photo and silhouette stay on this device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var captureButtons: some View {
        VStack(spacing: 12) {
            Button {
                showingCamera = true
            } label: {
                Label("Take a Full-Body Selfie", systemImage: "camera")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Import from Photos", systemImage: "photo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    private func previewSection(_ source: UIImage) -> some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                labeledPreview("Photo", image: source)
                labeledPreview("Silhouette", image: silhouetteImage, isBusy: isProcessing)
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                Button {
                    saveAvatar()
                } label: {
                    Label("Use This Avatar", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isProcessing || isSaving)

                Button("Start Over", role: .destructive) {
                    resetCapture()
                }
                .disabled(isProcessing || isSaving)
            }
        }
    }

    private func labeledPreview(_ title: String, image: UIImage?, isBusy: Bool = false) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(6)
                } else if isBusy {
                    ProgressView()
                } else {
                    Image(systemName: "person.crop.rectangle")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(maxWidth: .infinity)
    }

    @MainActor
    private func loadPickedImage(_ item: PhotosPickerItem?) async {
        guard let item else {
            return
        }

        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data)
        else {
            statusMessage = "That photo couldn't be loaded. Try a different one."
            return
        }

        handleImage(image, from: .photoLibrary)
    }

    @MainActor
    private func handleImage(_ image: UIImage, from source: ImageSource) {
        let resized = image.resizedToFit(maxPixelSize: 1600)
        sourceImage = resized
        silhouetteImage = nil
        imageSource = source
        isProcessing = true
        statusMessage = "Creating your silhouette on device…"

        Task {
            await generateSilhouette(from: resized)
        }
    }

    @MainActor
    private func generateSilhouette(from image: UIImage) async {
        do {
            let silhouette = try await Task.detached(priority: .userInitiated) {
                try PersonSilhouetteGenerator().makeSilhouette(from: image)
            }.value

            silhouetteImage = silhouette
            statusMessage = "Silhouette ready. Use it, or start over with a different photo."
        } catch {
            silhouetteImage = nil
            statusMessage = "A silhouette couldn't be created from this photo, so the original photo will be used. Better lighting and a plain background help."
        }

        isProcessing = false
    }

    @MainActor
    private func saveAvatar() {
        guard let sourceImage, !isSaving else {
            return
        }

        isSaving = true
        Task {
            do {
                let repository = AvatarRepository(modelContext: modelContext, mediaStore: mediaStore)
                try await repository.createAvatar(
                    sourceImage: sourceImage,
                    silhouetteImage: silhouetteImage,
                    capturedFrom: imageSource
                )
            } catch {
                errorMessage = error.localizedDescription
            }

            isSaving = false
        }
    }

    @MainActor
    private func resetCapture() {
        pickerItem = nil
        sourceImage = nil
        silhouetteImage = nil
        isProcessing = false
        statusMessage = nil
    }
}
