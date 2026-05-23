import CoreImage

struct MaskEffectPoint: Equatable, Identifiable {
    let id: UUID = .init()
    var x: Double
    var y: Double
}

struct MaskEffectSettings {
    var points: [MaskEffectPoint]
    var inverted: Bool
}

final class MaskEffect: VideoEffect, @unchecked Sendable {
    private var settings: MaskEffectSettings?
    private var cachedMaskImage: CIImage?
    private var cachedExtent: CGRect = .zero
    private var cachedPoints: [MaskEffectPoint] = []
    private var cachedInverted: Bool = false

    func setSettings(settings: MaskEffectSettings) {
        processorPipelineQueue.async {
            self.settings = settings
            self.cachedMaskImage = nil
        }
    }

    private func makeMaskImage(_ extent: CGRect, _ points: [MaskEffectPoint], _ inverted: Bool) -> CIImage? {
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
        let path = CGMutablePath()
        let first = points[0]
        path.move(to: CGPoint(x: first.x * Double(width), y: (1.0 - first.y) * Double(height)))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: point.x * Double(width), y: (1.0 - point.y) * Double(height)))
        }
        path.closeSubpath()
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
        let extent = image.extent
        let maskImage: CIImage
        if let cachedMaskImage,
           cachedExtent == extent,
           cachedPoints == points,
           cachedInverted == inverted
        {
            maskImage = cachedMaskImage
        } else {
            guard let newMaskImage = makeMaskImage(extent, points, inverted) else {
                return image
            }
            cachedMaskImage = newMaskImage
            cachedExtent = extent
            cachedPoints = points
            cachedInverted = inverted
            maskImage = newMaskImage
        }
        let blender = CIFilter.blendWithMask()
        blender.inputImage = image
        blender.maskImage = maskImage
        blender.backgroundImage = CIImage.empty()
        return blender.outputImage ?? image
    }
}
