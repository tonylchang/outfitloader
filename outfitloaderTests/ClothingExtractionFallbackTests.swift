import Testing
import UIKit
@testable import outfitloader

/// The MVP's extraction contract: when Vision cannot separate a clothing item,
/// the app must fall back to the original photo instead of blocking the flow.
@MainActor
struct ClothingExtractionFallbackTests {
    @Test func flatBackgroundImageThrowsInsteadOfProducingACutout() {
        let flat = TestImageFactory.makeImage(size: CGSize(width: 400, height: 400), color: .systemGray5)

        // On device this is ClothingForegroundExtractionError.noForegroundFound;
        // simulators without Vision inference support throw a Vision error
        // instead. Either way the contract holds: featureless input must throw
        // (triggering the app's original-photo fallback), never return a cutout.
        #expect(throws: (any Error).self) {
            _ = try ClothingForegroundExtractor().extractForeground(from: flat)
        }
    }

    @Test func photoSelectionFallsBackToOriginalWhenExtractionFails() {
        let selection = WardrobePhotoSelection()
        let original = TestImageFactory.makeImage(size: CGSize(width: 40, height: 40), color: .systemRed)
        selection.originalImage = original
        selection.extractedImage = nil
        selection.extractionFailed = true

        #expect(selection.previewImage === original)
        #expect(selection.processedImageForSave == nil)
    }

    @Test func photoSelectionRespectsUseExtractedToggle() {
        let selection = WardrobePhotoSelection()
        let original = TestImageFactory.makeImage(size: CGSize(width: 40, height: 40), color: .systemRed)
        let cutout = TestImageFactory.makeImage(size: CGSize(width: 30, height: 30), color: .systemGreen)
        selection.originalImage = original
        selection.extractedImage = cutout

        selection.useExtracted = true
        #expect(selection.previewImage === cutout)
        #expect(selection.processedImageForSave === cutout)

        selection.useExtracted = false
        #expect(selection.previewImage === original)
        #expect(selection.processedImageForSave == nil)
    }
}
