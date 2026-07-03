import UIKit

struct AvatarAdjustment: Equatable {
    var scale: CGFloat = 1
    var rotationRadians: CGFloat = 0
    var opacity: CGFloat = 1
}

struct ClothingPlacement: Equatable {
    var anchor: CGPoint = CGPoint(x: 0.5, y: 0.45)
    var scale: CGFloat = 0.42
    var rotationRadians: CGFloat = 0
    var opacity: CGFloat = 0.96
}

struct OutfitRenderLayer {
    var image: UIImage
    var placement: ClothingPlacement
    var zIndex: Int
}

struct TryOnComposer {
    func compose(
        avatar: UIImage,
        avatarAdjustment: AvatarAdjustment = AvatarAdjustment(),
        layers: [OutfitRenderLayer],
        outputSize: CGSize = CGSize(width: 1024, height: 1536)
    ) -> UIImage {
        let avatarImage = avatar.normalizedForProcessing()

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false

        return UIGraphicsImageRenderer(size: outputSize, format: format).image { renderContext in
            UIColor.systemBackground.setFill()
            renderContext.fill(CGRect(origin: .zero, size: outputSize))

            let canvas = CGRect(origin: .zero, size: outputSize).insetBy(dx: 48, dy: 48)
            let fittedAvatarRect = CGRect.aspectFit(size: avatarImage.size, in: canvas)
            let avatarRect = fittedAvatarRect.scaledFromCenter(by: avatarAdjustment.scale)

            let cgContext = renderContext.cgContext
            cgContext.saveGState()
            cgContext.translateBy(x: avatarRect.midX, y: avatarRect.midY)
            cgContext.rotate(by: avatarAdjustment.rotationRadians)
            cgContext.setAlpha(avatarAdjustment.opacity)
            avatarImage.draw(
                in: CGRect(
                    x: -avatarRect.width / 2,
                    y: -avatarRect.height / 2,
                    width: avatarRect.width,
                    height: avatarRect.height
                )
            )
            cgContext.restoreGState()

            for layer in layers.sorted(by: { $0.zIndex < $1.zIndex }) {
                let clothingImage = layer.image.normalizedForProcessing()
                guard clothingImage.size.width > 0 else {
                    continue
                }

                let placement = layer.placement
                let clothingWidth = avatarRect.width * placement.scale
                let clothingHeight = clothingWidth * clothingImage.size.height / clothingImage.size.width
                let center = CGPoint(
                    x: avatarRect.minX + avatarRect.width * placement.anchor.x,
                    y: avatarRect.minY + avatarRect.height * placement.anchor.y
                )

                cgContext.saveGState()
                cgContext.translateBy(x: center.x, y: center.y)
                cgContext.rotate(by: avatarAdjustment.rotationRadians + placement.rotationRadians)
                cgContext.setAlpha(placement.opacity)
                clothingImage.draw(
                    in: CGRect(
                        x: -clothingWidth / 2,
                        y: -clothingHeight / 2,
                        width: clothingWidth,
                        height: clothingHeight
                    )
                )
                cgContext.restoreGState()
            }
        }
    }
}
