import UIKit

extension UIImage {
    func normalizedForProcessing() -> UIImage {
        guard imageOrientation != .up else {
            return self
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func resizedToFit(maxPixelSize: CGFloat) -> UIImage {
        let normalized = normalizedForProcessing()
        let longestSide = max(normalized.size.width, normalized.size.height)
        guard longestSide > maxPixelSize else {
            return normalized
        }

        let ratio = maxPixelSize / longestSide
        let targetSize = CGSize(
            width: normalized.size.width * ratio,
            height: normalized.size.height * ratio
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            normalized.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

extension CGRect {
    static func aspectFit(size: CGSize, in bounds: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0, bounds.width > 0, bounds.height > 0 else {
            return .zero
        }

        let scale = min(bounds.width / size.width, bounds.height / size.height)
        let fittedSize = CGSize(width: size.width * scale, height: size.height * scale)

        return CGRect(
            x: bounds.midX - fittedSize.width / 2,
            y: bounds.midY - fittedSize.height / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }
}
