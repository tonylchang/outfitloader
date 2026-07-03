import CoreImage
import CoreVideo
import UIKit
import Vision

enum ClothingForegroundExtractionError: LocalizedError {
    case missingCGImage
    case noForegroundFound
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .missingCGImage:
            return "The selected clothing image could not be converted for Vision processing."
        case .noForegroundFound:
            return "Vision could not separate a foreground clothing item from the background."
        case .renderFailed:
            return "The transparent clothing image could not be rendered."
        }
    }
}

struct ClothingForegroundExtractor {
    func extractForeground(from image: UIImage) throws -> UIImage {
        let normalized = image.normalizedForProcessing().resizedToFit(maxPixelSize: 1600)
        guard let cgImage = normalized.cgImage else {
            throw ClothingForegroundExtractionError.missingCGImage
        }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first,
              !observation.allInstances.isEmpty
        else {
            throw ClothingForegroundExtractionError.noForegroundFound
        }

        let maskedPixelBuffer = try observation.generateMaskedImage(
            ofInstances: observation.allInstances,
            from: handler,
            croppedToInstancesExtent: true
        )

        let output = CIImage(cvPixelBuffer: maskedPixelBuffer)
        let context = CIContext(options: [.cacheIntermediates: false])
        guard let rendered = context.createCGImage(output, from: output.extent) else {
            throw ClothingForegroundExtractionError.renderFailed
        }

        return UIImage(cgImage: rendered, scale: normalized.scale, orientation: .up)
    }
}
