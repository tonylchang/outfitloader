import CoreImage
import CoreVideo
import UIKit
import Vision

enum SilhouetteGenerationError: LocalizedError {
    case missingCGImage
    case noPersonFound
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .missingCGImage:
            return "The selected image could not be converted for Vision processing."
        case .noPersonFound:
            return "Vision could not find a person in the image."
        case .renderFailed:
            return "The transparent silhouette could not be rendered."
        }
    }
}

struct PersonSilhouetteGenerator {
    func makeSilhouette(from image: UIImage) throws -> UIImage {
        let normalized = image.normalizedForProcessing().resizedToFit(maxPixelSize: 1600)
        guard let cgImage = normalized.cgImage else {
            throw SilhouetteGenerationError.missingCGImage
        }

        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first else {
            throw SilhouetteGenerationError.noPersonFound
        }

        let source = CIImage(cgImage: cgImage)
        let rawMask = CIImage(cvPixelBuffer: observation.pixelBuffer)
        let scaledMask = rawMask.transformed(
            by: CGAffineTransform(
                scaleX: source.extent.width / rawMask.extent.width,
                y: source.extent.height / rawMask.extent.height
            )
        )

        let transparentBackground = CIImage(
            color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)
        )
        .cropped(to: source.extent)

        let output = source.applyingFilter(
            "CIBlendWithMask",
            parameters: [
                kCIInputBackgroundImageKey: transparentBackground,
                kCIInputMaskImageKey: scaledMask
            ]
        )

        let context = CIContext(options: [.cacheIntermediates: false])
        guard let rendered = context.createCGImage(output, from: source.extent) else {
            throw SilhouetteGenerationError.renderFailed
        }

        return UIImage(cgImage: rendered, scale: normalized.scale, orientation: .up)
    }
}
