import CoreImage
@testable import Moblin
import Testing

struct EffectUtilsSuite {
    private let streamSize = CGSize(width: 1920, height: 1080)
    private let size = CGSize(width: 200, height: 100)

    private func layout(_ alignment: SettingsAlignment) -> SettingsWidgetLayout {
        var layout = SettingsWidgetLayout()
        layout.x = 10
        layout.y = 20
        layout.alignment = alignment
        return layout
    }

    private func position(_ alignment: SettingsAlignment) -> CGPoint {
        metalPetalLayerPosition(layout(alignment), size, streamSize)
    }

    @Test
    func metalPetalLayerPositionCorners() {
        #expect(position(.topLeft) == CGPoint(x: 292, y: 266))
        #expect(position(.topRight) == CGPoint(x: 1628, y: 266))
        #expect(position(.bottomLeft) == CGPoint(x: 292, y: 814))
        #expect(position(.bottomRight) == CGPoint(x: 1628, y: 814))
    }

    @Test
    func metalPetalLayerPositionCenters() {
        #expect(position(.topCenter) == CGPoint(x: 960, y: 266))
        #expect(position(.bottomCenter) == CGPoint(x: 960, y: 814))
        #expect(position(.leftCenter) == CGPoint(x: 292, y: 540))
        #expect(position(.rightCenter) == CGPoint(x: 1628, y: 540))
        #expect(position(.center) == CGPoint(x: 960, y: 540))
    }

    /// Same position as Core Image's move(), just in the upper left corner origin coordinate system.
    @Test
    func metalPetalLayerPositionMatchesCoreImage() {
        for alignment in SettingsAlignment.allCases {
            let layout = layout(alignment)
            let extent = CIImage.black
                .cropped(to: CGRect(origin: .zero, size: size))
                .move(layout, streamSize)
                .extent
            let expected = CGPoint(x: extent.midX, y: streamSize.height - extent.midY)
            let position = position(alignment)
            // Core Image's move() adds a pixel to get all the way to the right and to the top.
            #expect(abs(position.x - expected.x) <= 1)
            #expect(abs(position.y - expected.y) <= 1)
        }
    }
}
