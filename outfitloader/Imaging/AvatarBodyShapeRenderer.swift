import Foundation
import UIKit

struct AvatarBodyShapeAdjustment: Equatable {
    var heightCentimeters: Double?
    var shoulderAdjustment: Double
    var torsoAdjustment: Double
    var waistAdjustment: Double
    var hipAdjustment: Double
    var legAdjustment: Double

    static let neutral = AvatarBodyShapeAdjustment(
        heightCentimeters: nil,
        shoulderAdjustment: 0,
        torsoAdjustment: 0,
        waistAdjustment: 0,
        hipAdjustment: 0,
        legAdjustment: 0
    )

    var cacheKey: String {
        [
            heightCentimeters.map { String(format: "%.0f", $0) } ?? "nil",
            String(format: "%.2f", shoulderAdjustment),
            String(format: "%.2f", torsoAdjustment),
            String(format: "%.2f", waistAdjustment),
            String(format: "%.2f", hipAdjustment),
            String(format: "%.2f", legAdjustment)
        ].joined(separator: "|")
    }

    var isNeutral: Bool {
        heightCentimeters == nil
            && abs(shoulderAdjustment) < 0.001
            && abs(torsoAdjustment) < 0.001
            && abs(waistAdjustment) < 0.001
            && abs(hipAdjustment) < 0.001
            && abs(legAdjustment) < 0.001
    }
}

extension AvatarProfile {
    var bodyShapeAdjustment: AvatarBodyShapeAdjustment {
        AvatarBodyShapeAdjustment(
            heightCentimeters: heightCentimeters,
            shoulderAdjustment: shoulderAdjustment,
            torsoAdjustment: torsoAdjustment,
            waistAdjustment: waistAdjustment,
            hipAdjustment: hipAdjustment,
            legAdjustment: legAdjustment
        )
    }
}

/// Applies lightweight, user-controlled proportional warping to an avatar image.
/// This is a visual fit tool only; it does not infer or measure body traits.
struct AvatarBodyShapeRenderer {
    private static let rowCount = 96

    func render(_ image: UIImage, adjustment: AvatarBodyShapeAdjustment) -> UIImage {
        let normalized = image.normalizedForProcessing()
        guard !adjustment.isNeutral, let cgImage = normalized.cgImage else {
            return normalized
        }

        let heightMultiplier = heightMultiplier(for: adjustment)
        let maxWidthMultiplier = maxWidthMultiplier(for: adjustment)
        let outputSize = CGSize(
            width: max(normalized.size.width * maxWidthMultiplier, 1),
            height: max(normalized.size.height * heightMultiplier, 1)
        )
        let rowHeight = normalized.size.height / CGFloat(Self.rowCount)
        let pixelScaleX = CGFloat(cgImage.width) / normalized.size.width
        let pixelScaleY = CGFloat(cgImage.height) / normalized.size.height

        let format = UIGraphicsImageRendererFormat()
        format.scale = normalized.scale
        format.opaque = false

        return UIGraphicsImageRenderer(size: outputSize, format: format).image { _ in
            for row in 0..<Self.rowCount {
                let normalizedY = (CGFloat(row) + 0.5) / CGFloat(Self.rowCount)
                let sourceY = CGFloat(row) * rowHeight
                let sourceHeight = row == Self.rowCount - 1
                    ? normalized.size.height - sourceY
                    : rowHeight + 1
                let cropRect = CGRect(
                    x: 0,
                    y: sourceY * pixelScaleY,
                    width: CGFloat(cgImage.width),
                    height: min(sourceHeight * pixelScaleY, CGFloat(cgImage.height) - sourceY * pixelScaleY)
                ).integral

                guard cropRect.height > 0, let slice = cgImage.cropping(to: cropRect) else {
                    continue
                }

                let widthMultiplier = widthMultiplier(at: normalizedY, adjustment: adjustment)
                let destinationWidth = normalized.size.width * widthMultiplier
                let destinationRect = CGRect(
                    x: (outputSize.width - destinationWidth) / 2,
                    y: sourceY * heightMultiplier,
                    width: destinationWidth,
                    height: sourceHeight * heightMultiplier + (1 / max(pixelScaleX, 1))
                )

                UIImage(cgImage: slice, scale: normalized.scale, orientation: .up).draw(in: destinationRect)
            }
        }
    }

    private func heightMultiplier(for adjustment: AvatarBodyShapeAdjustment) -> CGFloat {
        let heightComponent: Double
        if let heightCentimeters = adjustment.heightCentimeters {
            heightComponent = ((heightCentimeters - 170) / 60).clamped(to: -1...1) * 0.10
        } else {
            heightComponent = 0
        }

        let legComponent = adjustment.legAdjustment.clamped(to: -1...1) * 0.04
        return CGFloat((1 + heightComponent + legComponent).clamped(to: 0.86...1.16))
    }

    private func maxWidthMultiplier(for adjustment: AvatarBodyShapeAdjustment) -> CGFloat {
        let maxPositive = max(
            adjustment.shoulderAdjustment,
            adjustment.torsoAdjustment,
            adjustment.waistAdjustment,
            adjustment.hipAdjustment,
            adjustment.legAdjustment,
            0
        )
        return CGFloat(1 + maxPositive.clamped(to: 0...1) * 0.18)
    }

    private func widthMultiplier(at y: CGFloat, adjustment: AvatarBodyShapeAdjustment) -> CGFloat {
        let shoulder = adjustment.shoulderAdjustment.clamped(to: -1...1) * 0.15 * gaussian(y, center: 0.28, width: 0.11)
        let torso = adjustment.torsoAdjustment.clamped(to: -1...1) * 0.10 * gaussian(y, center: 0.41, width: 0.17)
        let waist = adjustment.waistAdjustment.clamped(to: -1...1) * 0.13 * gaussian(y, center: 0.50, width: 0.08)
        let hip = adjustment.hipAdjustment.clamped(to: -1...1) * 0.14 * gaussian(y, center: 0.60, width: 0.10)
        let legs = adjustment.legAdjustment.clamped(to: -1...1) * 0.08 * gaussian(y, center: 0.78, width: 0.18)

        return CGFloat((1 + shoulder + torso + waist + hip + legs).clamped(to: 0.72...1.24))
    }

    private func gaussian(_ y: CGFloat, center: CGFloat, width: CGFloat) -> Double {
        let distance = Double((y - center) / width)
        return exp(-0.5 * distance * distance)
    }
}
