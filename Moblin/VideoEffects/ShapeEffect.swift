import CoreImage
import CoreImage.CIFilterBuiltins

struct ShapeEffectSettings {
    var cornerRadius: Float = 0
    var cornerRadiusTopLeft: Bool = true
    var cornerRadiusTopRight: Bool = true
    var cornerRadiusBottomLeft: Bool = true
    var cornerRadiusBottomRight: Bool = true
    var borderWidth: Double = 1.0
    var borderColor: CIColor = .black
    var cropEnabled: Bool = false
    var cropX: Double = 0.25
    var cropY: Double = 0.0
    var cropWidth: Double = 0.5
    var cropHeight: Double = 1.0

    func borderWidthAndScale(_ image: CGRect) -> (Double, Double, Double) {
        let borderWidth = 0.025 * borderWidth * min(image.height, image.width)
        let scaleX = (image.width + 2 * borderWidth) / image.width
        let scaleY = (image.height + 2 * borderWidth) / image.height
        return (borderWidth, scaleX, scaleY)
    }
}

private struct MaskImage {
    var extent: CGRect?
    var cornerRadius: Float?
    var cornerRadiusTopLeft: Bool?
    var cornerRadiusTopRight: Bool?
    var cornerRadiusBottomLeft: Bool?
    var cornerRadiusBottomRight: Bool?
    var image: CIImage?

    func get(extent: CGRect, settings: ShapeEffectSettings) -> CIImage? {
        guard extent == self.extent else {
            return nil
        }
        guard settings.cornerRadius == cornerRadius else {
            return nil
        }
        guard settings.cornerRadiusTopLeft == cornerRadiusTopLeft else {
            return nil
        }
        guard settings.cornerRadiusTopRight == cornerRadiusTopRight else {
            return nil
        }
        guard settings.cornerRadiusBottomLeft == cornerRadiusBottomLeft else {
            return nil
        }
        guard settings.cornerRadiusBottomRight == cornerRadiusBottomRight else {
            return nil
        }
        return image
    }

    mutating func set(extent: CGRect, settings: ShapeEffectSettings, image: CIImage?) {
        self.extent = extent
        cornerRadius = settings.cornerRadius
        cornerRadiusTopLeft = settings.cornerRadiusTopLeft
        cornerRadiusTopRight = settings.cornerRadiusTopRight
        cornerRadiusBottomLeft = settings.cornerRadiusBottomLeft
        cornerRadiusBottomRight = settings.cornerRadiusBottomRight
        self.image = image
    }
}

final class ShapeEffect: VideoEffect, @unchecked Sendable {
    private var settings: ShapeEffectSettings = .init()
    private var cachedMask = MaskImage()
    private var cachedBorderMask = MaskImage()

    func setSettings(settings: ShapeEffectSettings) {
        processorPipelineQueue.async {
            self.settings = settings
        }
    }

    private func makeMaskImage(_ extent: CGRect,
                               _ settings: ShapeEffectSettings,
                               _ cache: inout MaskImage) -> CIImage?
    {
        if let image = cache.get(extent: extent, settings: settings) {
            return image
        }
        let width = Int(extent.width)
        let height = Int(extent.height)
        guard width > 0, height > 0 else {
            return nil
        }
        let inset: CGFloat = 1.0
        let rect = extent
            .offsetBy(dx: inset, dy: inset)
            .insetBy(dx: inset, dy: inset)
        let cornerRadius = CGFloat(min(rect.height, rect.width)) / 2.0 * CGFloat(settings.cornerRadius)
        let cornerRadiusTopLeft = settings.cornerRadiusTopLeft ? cornerRadius : 0
        let cornerRadiusTopRight = settings.cornerRadiusTopRight ? cornerRadius : 0
        let cornerRadiusBottomLeft = settings.cornerRadiusBottomLeft ? cornerRadius : 0
        let cornerRadiusBottomRight = settings.cornerRadiusBottomRight ? cornerRadius : 0
        let minX = rect.minX
        let maxX = rect.maxX
        let minY = rect.minY
        let maxY = rect.maxY
        let path = CGMutablePath()
        path.move(to: CGPoint(x: minX + cornerRadiusTopLeft, y: maxY))
        path.addLine(to: CGPoint(x: maxX - cornerRadiusTopRight, y: maxY))
        if cornerRadiusTopRight > 0 {
            path.addArc(tangent1End: CGPoint(x: maxX, y: maxY),
                        tangent2End: CGPoint(x: maxX, y: maxY - cornerRadiusTopRight),
                        radius: cornerRadiusTopRight)
        }
        path.addLine(to: CGPoint(x: maxX, y: minY + cornerRadiusBottomRight))
        if cornerRadiusBottomRight > 0 {
            path.addArc(tangent1End: CGPoint(x: maxX, y: minY),
                        tangent2End: CGPoint(x: maxX - cornerRadiusBottomRight, y: minY),
                        radius: cornerRadiusBottomRight)
        }
        path.addLine(to: CGPoint(x: minX + cornerRadiusBottomLeft, y: minY))
        if cornerRadiusBottomLeft > 0 {
            path.addArc(tangent1End: CGPoint(x: minX, y: minY),
                        tangent2End: CGPoint(x: minX, y: minY + cornerRadiusBottomLeft),
                        radius: cornerRadiusBottomLeft)
        }
        path.addLine(to: CGPoint(x: minX, y: maxY - cornerRadiusTopLeft))
        if cornerRadiusTopLeft > 0 {
            path.addArc(tangent1End: CGPoint(x: minX, y: maxY),
                        tangent2End: CGPoint(x: minX + cornerRadiusTopLeft, y: maxY),
                        radius: cornerRadiusTopLeft)
        }
        path.closeSubpath()
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
        context.setFillColor(gray: 1.0, alpha: 1.0)
        context.addPath(path)
        context.fillPath()
        guard let cgImage = context.makeImage() else {
            return nil
        }
        let maskImage = CIImage(cgImage: cgImage)
        cache.set(extent: extent, settings: settings, image: maskImage)
        return cache.get(extent: extent, settings: settings)
    }

    private func makeSharpCornersImage(_ image: CIImage, _ settings: ShapeEffectSettings) -> CIImage {
        if settings.borderWidth == 0 {
            return image
        } else {
            let (borderWidth, scaleX, scaleY) = settings.borderWidthAndScale(image.extent)
            let borderImage = CIImage(color: settings.borderColor)
                .cropped(to: image.extent)
                .scaled(x: scaleX, y: scaleY)
                .translated(x: -borderWidth, y: -borderWidth)
            return image.composited(over: borderImage)
        }
    }

    private func makeRoundedCornersImage(_ image: CIImage, _ settings: ShapeEffectSettings) -> CIImage {
        if settings.borderWidth == 0 {
            let roundedCornersBlender = CIFilter.blendWithMask()
            roundedCornersBlender.inputImage = image
            roundedCornersBlender.maskImage = makeMaskImage(image.extent, settings, &cachedMask)
            return roundedCornersBlender.outputImage ?? image
        } else {
            let (borderWidth, scaleX, scaleY) = settings.borderWidthAndScale(image.extent)
            let borderImage = CIImage(color: settings.borderColor)
                .cropped(to: image.extent)
                .scaled(x: scaleX, y: scaleY)
                .translated(x: -borderWidth, y: -borderWidth)
            let roundedCornersBlender = CIFilter.blendWithMask()
            roundedCornersBlender.inputImage = borderImage
            roundedCornersBlender.maskImage = makeMaskImage(borderImage.extent, settings, &cachedBorderMask)
            guard let roundedBorderImage = roundedCornersBlender.outputImage else {
                return image
            }
            roundedCornersBlender.inputImage = image
            roundedCornersBlender.maskImage = makeMaskImage(image.extent, settings, &cachedMask)
            guard let widgetImage = roundedCornersBlender.outputImage else {
                return image
            }
            return widgetImage.composited(over: roundedBorderImage)
        }
    }

    private func crop(_ image: CIImage) -> CIImage {
        let cropX = toPixels(100 * settings.cropX, image.extent.width)
        let cropY = toPixels(100 * settings.cropY, image.extent.height)
        let cropWidth = toPixels(100 * settings.cropWidth, image.extent.width)
        let cropHeight = toPixels(100 * settings.cropHeight, image.extent.height)
        return image
            .cropped(to: .init(
                x: cropX,
                y: image.extent.height - cropY - cropHeight,
                width: cropWidth,
                height: cropHeight
            ))
            .translated(x: -cropX, y: -(image.extent.height - cropY - cropHeight))
    }

    override func executeEarly(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        if settings.cropEnabled {
            crop(image)
        } else {
            image
        }
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        if settings.cornerRadius == 0 {
            makeSharpCornersImage(image, settings)
        } else {
            makeRoundedCornersImage(image, settings)
        }
    }
}
