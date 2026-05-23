import CoreImage

struct MaskEffectPoint: Codable, Equatable {
    var x: Double
    var y: Double
}

struct MaskEffectSettings {
    var points: [MaskEffectPoint]
}

final class MaskEffect: VideoEffect, @unchecked Sendable {
    private var settings: MaskEffectSettings = .init(points: MaskEffect.defaultPoints)

    static let defaultPoints: [MaskEffectPoint] = [
        .init(x: 0.5, y: 0.0),
        .init(x: 1.0, y: 0.65),
        .init(x: 0.8, y: 1.0),
        .init(x: 0.2, y: 1.0),
        .init(x: 0.0, y: 0.65),
    ]

    func setSettings(settings: MaskEffectSettings) {
        processorPipelineQueue.async {
            self.settings = settings
        }
    }

    private func makeMaskImage(_ extent: CGRect, _ points: [MaskEffectPoint]) -> CIImage? {
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
        context.setFillColor(gray: 0.0, alpha: 1.0)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(gray: 1.0, alpha: 1.0)
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
        let points = settings.points
        guard points.count >= 3 else {
            return image
        }
        guard let maskImage = makeMaskImage(image.extent, points) else {
            return image
        }
        let blender = CIFilter.blendWithMask()
        blender.inputImage = image
        blender.maskImage = maskImage
        blender.backgroundImage = CIImage.empty()
        return blender.outputImage ?? image
    }
}
