import CoreImage
import MetalPetal

private func shapeBorderWidthPixels(_ borderWidth: Double, _ size: CGSize) -> Double {
    0.025 * borderWidth * min(size.height, size.width)
}

private func shapeCornerRadiusPixels(_ cornerRadius: Float, _ size: CGSize) -> Float {
    Float(min(size.height, size.width)) / 2 * cornerRadius
}

struct ShapeEffectSettings {
    var cornerRadius: Float = 0
    var borderWidth: Double = 1.0
    var borderColor: CIColor = .black
    var cropEnabled: Bool = false
    var cropX: Double = 0.25
    var cropY: Double = 0.0
    var cropWidth: Double = 0.5
    var cropHeight: Double = 1.0

    func borderWidthAndScale(_ image: CGRect) -> (Double, Double, Double) {
        let borderWidth = shapeBorderWidthPixels(borderWidth, image.size)
        let scaleX = (image.width + 2 * borderWidth) / image.width
        let scaleY = (image.height + 2 * borderWidth) / image.height
        return (borderWidth, scaleX, scaleY)
    }

    func cropRegion(_ region: CGRect) -> CGRect {
        CGRect(x: region.minX + cropX * region.width,
               y: region.minY + cropY * region.height,
               width: cropWidth * region.width,
               height: cropHeight * region.height)
    }
}

struct WidgetShapePlacement {
    let scale: Double
    let size: CGSize
    let borderWidth: Double
    let borderSize: CGSize
    let center: CGPoint
}

struct WidgetShape {
    var contentRegion: CGRect
    var cornerRadius: Float = 0
    var borderWidth: Double = 0
    var borderColor: CIColor = .black
    var rotation: Double = 0

    mutating func apply(_ settings: ShapeEffectSettings) {
        if settings.cropEnabled {
            contentRegion = settings.cropRegion(contentRegion)
        }
        cornerRadius = settings.cornerRadius
        borderWidth = settings.borderWidth
        borderColor = settings.borderColor
    }

    func placement(_ layout: SettingsWidgetLayout,
                   _ streamSize: CGSize,
                   _ resize: Bool = true) -> WidgetShapePlacement
    {
        let scale = resize ? layoutScale(layout, rotated(contentRegion.size), streamSize) : 1
        let size = CGSize(width: contentRegion.width * scale, height: contentRegion.height * scale)
        let borderWidth = shapeBorderWidthPixels(borderWidth, size)
        let borderSize = CGSize(width: size.width + 2 * borderWidth, height: size.height + 2 * borderWidth)
        return WidgetShapePlacement(scale: scale,
                                    size: size,
                                    borderWidth: borderWidth,
                                    borderSize: borderSize,
                                    center: layoutCenter(layout, rotated(borderSize), streamSize))
    }

    func cornerRadiusPixels(_ size: CGSize) -> Float {
        shapeCornerRadiusPixels(cornerRadius, size)
    }

    func rotated(_ size: CGSize) -> CGSize {
        if isQuarterTurn() {
            CGSize(width: size.height, height: size.width)
        } else {
            size
        }
    }

    func rotationRadians() -> Double {
        rotation * .pi / 180
    }

    func mirrorFlipOptions() -> MTILayer.FlipOptions {
        if isQuarterTurn() {
            .flipVertically
        } else {
            .flipHorizontally
        }
    }

    private func isQuarterTurn() -> Bool {
        rotation == 90 || rotation == 270
    }
}

private struct MaskImage {
    var extent: CGRect?
    var cornerRadius: Float?
    var image: CIImage?

    func get(extent: CGRect, settings: ShapeEffectSettings) -> CIImage? {
        guard extent == self.extent else {
            return nil
        }
        guard settings.cornerRadius == cornerRadius else {
            return nil
        }
        return image
    }

    mutating func set(extent: CGRect, settings: ShapeEffectSettings, image: CIImage?) {
        self.extent = extent
        cornerRadius = settings.cornerRadius
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
        let roundedRectangleGenerator = CIFilter.roundedRectangleGenerator()
        roundedRectangleGenerator.color = .green
        // Slightly smaller to remove ~1px black line around image.
        var maskExtent = extent
        maskExtent.origin.x += 1
        maskExtent.origin.y += 1
        maskExtent.size.width -= 2
        maskExtent.size.height -= 2
        roundedRectangleGenerator.extent = maskExtent
        roundedRectangleGenerator.radius = shapeCornerRadiusPixels(settings.cornerRadius, extent.size)
        cache.set(extent: extent, settings: settings, image: roundedRectangleGenerator.outputImage)
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
        let region = settings.cropRegion(CGRect(origin: .zero, size: image.extent.size))
        let cropY = image.extent.height - region.maxY
        return image
            .cropped(to: .init(x: region.minX, y: cropY, width: region.width, height: region.height))
            .translated(x: -region.minX, y: -cropY)
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

    override func modifyWidgetShape(_ shape: inout WidgetShape) {
        shape.apply(settings)
    }
}
