import CoreImage
import CoreImage.CIFilterBuiltins

struct MaskEffectPoint: Equatable {
    var x: Double
    var y: Double
}

struct MaskEffectSettings: Equatable {
    var points: [MaskEffectPoint]
    var inverted: Bool
    var tension: Double
    var backgroundType: SettingsMaskBackgroundType
    var backgroundColor: RgbColor
    var backgroundColor2: RgbColor
}

private let checkerboardSquareCount: Float = 20.0

func makeCatmullRomPath(_ points: [CGPoint], tension: CGFloat) -> CGMutablePath {
    let numberOfPoints = points.count
    let path = CGMutablePath()
    path.move(to: points[0])
    for i in 0 ..< numberOfPoints {
        let point0 = points[(i - 1 + numberOfPoints) % numberOfPoints]
        let point1 = points[i]
        let point2 = points[(i + 1) % numberOfPoints]
        let point3 = points[(i + 2) % numberOfPoints]
        let cpoint1 = CGPoint(
            x: point1.x + (point2.x - point0.x) * tension,
            y: point1.y + (point2.y - point0.y) * tension
        )
        let cpoint2 = CGPoint(
            x: point2.x - (point3.x - point1.x) * tension,
            y: point2.y - (point3.y - point1.y) * tension
        )
        path.addCurve(to: point2, control1: cpoint1, control2: cpoint2)
    }
    path.closeSubpath()
    return path
}

private func makeCiColor(_ color: RgbColor) -> CIColor {
    CIColor(
        red: CGFloat(color.red) / 255.0,
        green: CGFloat(color.green) / 255.0,
        blue: CGFloat(color.blue) / 255.0
    )
}

final class MaskEffect: VideoEffect, @unchecked Sendable {
    private var settings: MaskEffectSettings?
    private var cachedSettings: MaskEffectSettings?
    private var cachedExtent: CGRect = .zero
    private var cachedMaskImage: CIImage?
    private var cachedBackgroundImage: CIImage?

    func setSettings(settings: MaskEffectSettings) {
        processorPipelineQueue.async {
            self.settings = settings
            self.cachedSettings = nil
            self.cachedMaskImage = nil
            self.cachedBackgroundImage = nil
        }
    }

    private func makeMaskImage(_ extent: CGRect, _ settings: MaskEffectSettings) -> CIImage? {
        guard settings.points.count >= 3 else {
            return nil
        }
        let width = Int(extent.width)
        let height = Int(extent.height)
        guard width > 0, height > 0 else {
            return nil
        }
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }
        let backgroundGray: CGFloat = settings.inverted ? 1.0 : 0.0
        let polygonGray: CGFloat = settings.inverted ? 0.0 : 1.0
        context.setFillColor(gray: backgroundGray, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(gray: polygonGray, alpha: 1.0)
        let screenPoints = settings.points.map {
            CGPoint(x: $0.x * Double(width), y: (1.0 - $0.y) * Double(height))
        }
        let path = makeCatmullRomPath(screenPoints, tension: settings.tension)
        context.addPath(path)
        context.fillPath()
        guard let cgImage = context.makeImage() else {
            return nil
        }
        return CIImage(cgImage: cgImage).translated(x: extent.minX, y: extent.minY)
    }

    private func makeBackgroundImage(_ extent: CGRect,
                                     _ settings: MaskEffectSettings) -> CIImage
    {
        switch settings.backgroundType {
        case .transparent:
            return CIImage.empty()
        case .solid:
            return CIImage(color: makeCiColor(settings.backgroundColor)).cropped(to: extent)
        case .checkerboard:
            let filter = CIFilter.checkerboardGenerator()
            filter.color0 = makeCiColor(settings.backgroundColor)
            filter.color1 = makeCiColor(settings.backgroundColor2)
            filter.width = Float(min(extent.width, extent.height)) / checkerboardSquareCount
            filter.sharpness = 1.0
            filter.center = CGPoint(x: extent.midX, y: extent.midY)
            return (filter.outputImage?.cropped(to: extent)) ?? CIImage.empty()
        }
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        guard let settings else {
            return image
        }
        let extent = image.extent
        let maskImage: CIImage
        let backgroundImage: CIImage
        if let cachedMaskImage, let cachedBackgroundImage, cachedSettings == settings,
           cachedExtent == extent
        {
            maskImage = cachedMaskImage
            backgroundImage = cachedBackgroundImage
        } else {
            guard let newMaskImage = makeMaskImage(extent, settings) else {
                return image
            }
            cachedMaskImage = newMaskImage
            cachedSettings = settings
            cachedExtent = extent
            maskImage = newMaskImage
            backgroundImage = makeBackgroundImage(extent, settings)
            cachedBackgroundImage = backgroundImage
        }
        let blender = CIFilter.blendWithMask()
        blender.inputImage = image
        blender.maskImage = maskImage
        blender.backgroundImage = backgroundImage
        return blender.outputImage ?? image
    }
}
