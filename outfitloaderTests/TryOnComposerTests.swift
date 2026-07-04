import Testing
import UIKit
@testable import outfitloader

/// Pure render tests: compose known solid-color inputs and assert on sampled
/// output pixels. Geometry constants follow the composer's default 1024x1536
/// output with a 48pt inset canvas.
@MainActor
struct TryOnComposerTests {
    private let avatar = TestImageFactory.makeImage(size: CGSize(width: 64, height: 128), color: .red)

    /// A 64x128 avatar aspect-fit into the 928x1440 canvas fills 720x1440 at
    /// x 152...872, y 48...1488. The default anchor (0.5, 0.45) lands at (512, 696).
    private let clothingCenter = CGPoint(x: 512, y: 696)
    private let avatarOnlyPoint = CGPoint(x: 512, y: 1200)

    @Test func outputMatchesRequestedSize() {
        let output = TryOnComposer().compose(avatar: avatar, layers: [])

        #expect(output.size == CGSize(width: 1024, height: 1536))
        #expect(output.scale == 1)
    }

    @Test func avatarRendersInsideCanvasAndBackgroundFillsOutside() throws {
        let output = TryOnComposer().compose(avatar: avatar, layers: [])

        let avatarPixel = try #require(pixel(at: avatarOnlyPoint, in: output))
        #expect(avatarPixel.r > 200)
        #expect(avatarPixel.g < 80)

        // (10, 10) is inside the 48pt inset border, so only background paints there.
        let border = try #require(pixel(at: CGPoint(x: 10, y: 10), in: output))
        #expect(border.r > 200)
        #expect(border.g > 200)
        #expect(border.b > 200)
    }

    @Test func backgroundStaysWhiteWhenComposedUnderDarkAppearance() throws {
        // Previews are stored images; the background must not depend on the
        // appearance that happened to be active at save time.
        var composed: UIImage?
        UITraitCollection(userInterfaceStyle: .dark).performAsCurrent {
            composed = TryOnComposer().compose(avatar: avatar, layers: [])
        }

        let output = try #require(composed)
        let border = try #require(pixel(at: CGPoint(x: 10, y: 10), in: output))
        #expect(border.r > 240)
        #expect(border.g > 240)
        #expect(border.b > 240)
    }

    @Test func clothingLayerDrawsOverAvatarAtItsAnchor() throws {
        let clothing = TestImageFactory.makeImage(size: CGSize(width: 40, height: 40), color: .blue)
        let layer = OutfitRenderLayer(image: clothing, placement: ClothingPlacement(opacity: 1), zIndex: 1)

        let output = TryOnComposer().compose(avatar: avatar, layers: [layer])

        let sample = try #require(pixel(at: clothingCenter, in: output))
        #expect(sample.b > 200)
        #expect(sample.r < 80)
    }

    @Test func higherZIndexDrawsOnTop() throws {
        let bottom = OutfitRenderLayer(
            image: TestImageFactory.makeImage(size: CGSize(width: 40, height: 40), color: .green),
            placement: ClothingPlacement(opacity: 1),
            zIndex: 1
        )
        let top = OutfitRenderLayer(
            image: TestImageFactory.makeImage(size: CGSize(width: 40, height: 40), color: .blue),
            placement: ClothingPlacement(opacity: 1),
            zIndex: 2
        )

        // Pass them bottom-last to prove the composer sorts by zIndex rather
        // than relying on array order.
        let output = TryOnComposer().compose(avatar: avatar, layers: [top, bottom])

        let sample = try #require(pixel(at: clothingCenter, in: output))
        #expect(sample.b > 200)
        #expect(sample.g < 80)
    }

    @Test func semiTransparentLayerBlendsWithAvatar() throws {
        var placement = ClothingPlacement()
        placement.opacity = 0.5
        let layer = OutfitRenderLayer(
            image: TestImageFactory.makeImage(size: CGSize(width: 40, height: 40), color: .blue),
            placement: placement,
            zIndex: 1
        )

        let output = TryOnComposer().compose(avatar: avatar, layers: [layer])

        // Half-opacity blue over red must show both channels, not either extreme.
        let sample = try #require(pixel(at: clothingCenter, in: output))
        #expect(sample.r > 80 && sample.r < 200)
        #expect(sample.b > 80 && sample.b < 200)
    }

    @Test func zeroOpacityLayerLeavesAvatarVisible() throws {
        var placement = ClothingPlacement()
        placement.opacity = 0
        let layer = OutfitRenderLayer(
            image: TestImageFactory.makeImage(size: CGSize(width: 40, height: 40), color: .blue),
            placement: placement,
            zIndex: 1
        )

        let output = TryOnComposer().compose(avatar: avatar, layers: [layer])

        let sample = try #require(pixel(at: clothingCenter, in: output))
        #expect(sample.r > 200)
        #expect(sample.b < 80)
    }

    private func pixel(at point: CGPoint, in image: UIImage) -> (r: Int, g: Int, b: Int, a: Int)? {
        guard let cgImage = image.cgImage else {
            return nil
        }

        var data = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &data,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        // Position the image so the requested top-left-origin pixel lands at
        // the context's single bottom-left-origin pixel.
        let height = CGFloat(cgImage.height)
        context.draw(
            cgImage,
            in: CGRect(
                x: -point.x,
                y: -(height - point.y - 1),
                width: CGFloat(cgImage.width),
                height: height
            )
        )

        return (r: Int(data[0]), g: Int(data[1]), b: Int(data[2]), a: Int(data[3]))
    }
}
