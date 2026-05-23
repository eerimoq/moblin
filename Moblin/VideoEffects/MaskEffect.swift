import CoreImage

struct MaskEffectPoint: Equatable, Identifiable {
    let id: UUID = .init()
    var x: Double
    var y: Double
}

struct MaskEffectSettings {
    var points: [MaskEffectPoint]
    var inverted: Bool
    var smooth: Bool
}

// Catmull-Rom tension: 1/6 gives a standard smooth spline.
private let catmullRomTension: CGFloat = 1.0 / 6.0

// Build a smooth closed Catmull-Rom spline path through the given screen-space points.
func makeCatmullRomPath(_ pts: [CGPoint]) -> CGMutablePath {
    let n = pts.count
    let path = CGMutablePath()
    path.move(to: pts[0])
    for i in 0 ..< n {
        let p0 = pts[(i - 1 + n) % n]
        let p1 = pts[i]
        let p2 = pts[(i + 1) % n]
        let p3 = pts[(i + 2) % n]
        let cp1 = CGPoint(
            x: p1.x + (p2.x - p0.x) * catmullRomTension,
            y: p1.y + (p2.y - p0.y) * catmullRomTension
        )
        let cp2 = CGPoint(
            x: p2.x - (p3.x - p1.x) * catmullRomTension,
            y: p2.y - (p3.y - p1.y) * catmullRomTension
        )
        path.addCurve(to: p2, control1: cp1, control2: cp2)
    }
    path.closeSubpath()
    return path
}

final class MaskEffect: VideoEffect, @unchecked Sendable {
    private var settings: MaskEffectSettings?
    private var cachedMaskImage: CIImage?
    private var cachedExtent: CGRect = .zero
    private var cachedPoints: [MaskEffectPoint] = []
    private var cachedInverted: Bool = false
    private var cachedSmooth: Bool = false

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
        _ smooth: Bool
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
            path = makeCatmullRomPath(screenPoints)
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

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        guard let settings else {
            return image
        }
        let points = settings.points
        let inverted = settings.inverted
        let smooth = settings.smooth
        let extent = image.extent
        let maskImage: CIImage
        if let cachedMaskImage,
           cachedExtent == extent,
           cachedPoints == points,
           cachedInverted == inverted,
           cachedSmooth == smooth
        {
            maskImage = cachedMaskImage
        } else {
            guard let newMaskImage = makeMaskImage(extent, points, inverted, smooth) else {
                return image
            }
            cachedMaskImage = newMaskImage
            cachedExtent = extent
            cachedPoints = points
            cachedInverted = inverted
            cachedSmooth = smooth
            maskImage = newMaskImage
        }
        let blender = CIFilter.blendWithMask()
        blender.inputImage = image
        blender.maskImage = maskImage
        blender.backgroundImage = CIImage.empty()
        return blender.outputImage ?? image
    }
}
