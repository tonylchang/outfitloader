import Observation
import PhotosUI
import SwiftUI
import UIKit

@MainActor
@Observable
final class WardrobePhotoSelection {
    var originalImage: UIImage?
    var extractedImage: UIImage?
    var useExtracted = true
    var isExtracting = false
    var extractionFailed = false
    var imageSource: ImageSource = .photoLibrary
    var errorMessage: String?

    var previewImage: UIImage? {
        if let extractedImage, useExtracted {
            return extractedImage
        }

        return originalImage
    }

    var processedImageForSave: UIImage? {
        useExtracted ? extractedImage : nil
    }

    func loadPickedImage(_ item: PhotosPickerItem?) async {
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

    func handleImage(_ image: UIImage, from source: ImageSource) {
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
}
