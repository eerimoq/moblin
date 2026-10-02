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
        layoutCenter(layout(alignment), size, streamSize)
    }

    @Test
    func layoutCenterCorners() {
        #expect(position(.topLeft) == CGPoint(x: 292, y: 266))
        #expect(position(.topRight) == CGPoint(x: 1628, y: 266))
        #expect(position(.bottomLeft) == CGPoint(x: 292, y: 814))
        #expect(position(.bottomRight) == CGPoint(x: 1628, y: 814))
    }

    @Test
    func layoutCenterCenters() {
        #expect(position(.topCenter) == CGPoint(x: 960, y: 266))
        #expect(position(.bottomCenter) == CGPoint(x: 960, y: 814))
        #expect(position(.leftCenter) == CGPoint(x: 292, y: 540))
        #expect(position(.rightCenter) == CGPoint(x: 1628, y: 540))
        #expect(position(.center) == CGPoint(x: 960, y: 540))
    }

    /// Same position as Core Image's move(), just in the upper left corner origin coordinate system.
    @Test
    func layoutCenterMatchesCoreImage() {
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

    @Test
    func layoutScaleFitsInsideLayoutSize() {
        var layout = SettingsWidgetLayout()
        layout.size = 50
        #expect(layoutScale(layout, CGSize(width: 1920, height: 1080), streamSize) == 0.5)
        #expect(layoutScale(layout, CGSize(width: 480, height: 1080), streamSize) == 0.5)
        #expect(layoutScale(layout, CGSize(width: 1920, height: 270), streamSize) == 0.5)
    }

    @Test
    func widgetShapePlacement() {
        var layout = layout(.bottomRight)
        layout.size = 50
        let shape = WidgetShape(contentRegion: CGRect(x: 100, y: 50, width: 400, height: 200))
        let placement = shape.placement(layout, streamSize)
        #expect(placement.scale == 2.4)
        #expect(placement.size == CGSize(width: 960, height: 480))
        #expect(placement.borderWidth == 0)
        #expect(placement.borderSize == placement.size)
        #expect(placement.center == CGPoint(x: 1248, y: 624))
    }

    @Test
    func widgetShapePlacementNoResize() {
        let shape = WidgetShape(contentRegion: CGRect(origin: .zero, size: size))
        let placement = shape.placement(layout(.topLeft), streamSize, false)
        #expect(placement.scale == 1)
        #expect(placement.size == size)
        #expect(placement.center == position(.topLeft))
    }

    @Test
    func widgetShapePlacementRotatedWithBorder() {
        var layout = layout(.topLeft)
        layout.size = 50
        var shape = WidgetShape(contentRegion: CGRect(x: 0, y: 0, width: 400, height: 200), rotation: 90)
        shape.borderWidth = 2
        let placement = shape.placement(layout, streamSize)
        #expect(placement.scale == 1.35)
        #expect(placement.size == CGSize(width: 540, height: 270))
        #expect(placement.borderWidth == 13.5)
        #expect(placement.borderSize == CGSize(width: 567, height: 297))
        #expect(placement.center == CGPoint(x: 340.5, y: 499.5))
        #expect(shape.cornerRadiusPixels(placement.size) == 0)
    }

    @Test
    func widgetShapeApplySettings() {
        var shape = WidgetShape(contentRegion: CGRect(x: 100, y: 50, width: 400, height: 200))
        shape.apply(ShapeEffectSettings(cornerRadius: 0.5,
                                        borderWidth: 2,
                                        cropEnabled: true,
                                        cropX: 0.25,
                                        cropY: 0.5,
                                        cropWidth: 0.5,
                                        cropHeight: 0.25))
        #expect(shape.contentRegion == CGRect(x: 200, y: 150, width: 200, height: 50))
        #expect(shape.borderWidth == 2)
        #expect(shape.cornerRadiusPixels(CGSize(width: 200, height: 50)) == 12.5)
    }
}
