import CoreImage
import CoreImage.CIFilterBuiltins

struct MaskEffectPoint: Equatable {
    var x: Double
    var y: Double
}

struct MaskEffectSettings {
    var points: [MaskEffectPoint]
    var inverted: Bool
    var smooth: Bool
    var tension: Double
    var backgroundType: SettingsMaskBackgroundType
    var backgroundRgbColor: RgbColor
    var backgroundRgbColor2: RgbColor
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
    private var cachedMaskImage: CIImage?
    private var cachedExtent: CGRect = .zero
    private var cachedPoints: [MaskEffectPoint] = []
    private var cachedInverted: Bool = false
    private var cachedSmooth: Bool = false
    private var cachedTension: Double = -1

    func setSettings(settings: MaskEffectSettings) {
        processorPipelineQueue.async {
            self.settings = settings
            self.cachedMaskImage = nil
        }
    }

    private func makeMaskImage(
        _ extent: CGRect,
        _ points: [MaskEffectPoint],
        _ inverted: Bool,
        _ smooth: Bool,
        _ catmullRomTension: Double
    ) -> CIImage? {
        guard points.count >= 3 else {
            return nil
        }
        let width = Int(extent.width)
        let height = Int(extent.height)
        guard width > 0, height > 0 else {
            return nil
        }
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }
        let backgroundGray: CGFloat = inverted ? 1.0 : 0.0
        let polygonGray: CGFloat = inverted ? 0.0 : 1.0
        context.setFillColor(gray: backgroundGray, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(gray: polygonGray, alpha: 1.0)
        let screenPoints = points.map {
            CGPoint(x: $0.x * Double(width), y: (1.0 - $0.y) * Double(height))
        }
        let path: CGPath
        if smooth {
            path = makeCatmullRomPath(screenPoints, tension: catmullRomTension)
        } else {
            let mutablePath = CGMutablePath()
            mutablePath.move(to: screenPoints[0])
            for pt in screenPoints.dropFirst() {
                mutablePath.addLine(to: pt)
            }
            mutablePath.closeSubpath()
            path = mutablePath
        }
        context.addPath(path)
        context.fillPath()
        guard let cgImage = context.makeImage() else {
            return nil
        }
        return CIImage(cgImage: cgImage).translated(x: extent.minX, y: extent.minY)
    }

    private func makeBackgroundImage(_ extent: CGRect, _ type: SettingsMaskBackgroundType,
                                     _ color: RgbColor, _ color2: RgbColor) -> CIImage
    {
        switch type {
        case .transparent:
            return CIImage.empty()
        case .solid:
            return CIImage(color: makeCiColor(color)).cropped(to: extent)
        case .checkerboard:
            let filter = CIFilter.checkerboardGenerator()
            filter.color0 = makeCiColor(color)
            filter.color1 = makeCiColor(color2)
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
        let points = settings.points
        let inverted = settings.inverted
        let smooth = settings.smooth
        let tension = settings.tension
        let extent = image.extent
        let maskImage: CIImage
        if let cachedMaskImage,
           cachedExtent == extent,
           cachedPoints == points,
           cachedInverted == inverted,
           cachedSmooth == smooth,
           cachedTension == tension
        {
            maskImage = cachedMaskImage
        } else {
            guard let newMaskImage = makeMaskImage(extent, points, inverted, smooth, tension) else {
                return image
            }
            cachedMaskImage = newMaskImage
            cachedExtent = extent
            cachedPoints = points
            cachedInverted = inverted
            cachedSmooth = smooth
            cachedTension = tension
            maskImage = newMaskImage
        }
        let blender = CIFilter.blendWithMask()
        blender.inputImage = image
        blender.maskImage = maskImage
        blender.backgroundImage = makeBackgroundImage(
            extent,
            settings.backgroundType,
            settings.backgroundRgbColor,
            settings.backgroundRgbColor2
        )
        return blender.outputImage ?? image
    }
}
