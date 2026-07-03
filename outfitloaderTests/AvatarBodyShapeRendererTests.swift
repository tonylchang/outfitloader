import Testing
import UIKit
@testable import outfitloader

@MainActor
struct AvatarBodyShapeRendererTests {
    @Test func neutralAdjustmentPreservesImageSize() {
        let source = TestImageFactory.makeImage(size: CGSize(width: 40, height: 80), color: .systemBlue)

        let rendered = AvatarBodyShapeRenderer().render(source, adjustment: .neutral)

        #expect(rendered.size == source.size)
        #expect(rendered.scale == source.scale)
    }

    @Test func positiveHeightAndShoulderAdjustmentsExpandCanvas() {
        let source = TestImageFactory.makeImage(size: CGSize(width: 40, height: 80), color: .systemTeal)
        let adjustment = AvatarBodyShapeAdjustment(
            heightCentimeters: 200,
            shoulderAdjustment: 1,
            torsoAdjustment: 0,
            waistAdjustment: 0,
            hipAdjustment: 0,
            legAdjustment: 1
        )

        let rendered = AvatarBodyShapeRenderer().render(source, adjustment: adjustment)

        #expect(rendered.size.width > source.size.width)
        #expect(rendered.size.height > source.size.height)
    }

    @Test func cacheKeyRoundsAdjustmentsForStableRenderIdentity() {
        let adjustment = AvatarBodyShapeAdjustment(
            heightCentimeters: 171.2,
            shoulderAdjustment: 0.234,
            torsoAdjustment: -0.155,
            waistAdjustment: 0,
            hipAdjustment: 0.499,
            legAdjustment: -0.004
        )

        #expect(adjustment.cacheKey == "171|0.23|-0.15|0.00|0.50|-0.00")
    }
}
