import AVFoundation
import CoreImage
import Vision

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
        let borderWidth = 0.025 * borderWidth * min(image.height, image.width)
        let scaleX = (image.width + 2 * borderWidth) / image.width
        let scaleY = (image.height + 2 * borderWidth) / image.height
        return (borderWidth, scaleX, scaleY)
    }
}

final class ShapeEffect: VideoEffect {
    private var settings: ShapeEffectSettings = .init()

    override func getName() -> String {
        return "Shape effect"
    }

    func setSettings(settings: ShapeEffectSettings) {
        processorPipelineQueue.async {
            self.settings = settings
        }
    }

    private func makeRoundedRectangleMask(
        _ videoSourceImage: CIImage,
        _ cornerRadius: Float
    ) -> CIImage? {
        let roundedRectangleGenerator = CIFilter.roundedRectangleGenerator()
        roundedRectangleGenerator.color = .green
        // Slightly smaller to remove ~1px black line around image.
        var extent = videoSourceImage.extent
        extent.origin.x += 1
        extent.origin.y += 1
        extent.size.width -= 2
        extent.size.height -= 2
        roundedRectangleGenerator.extent = extent
        var radiusPixels = Float(min(videoSourceImage.extent.height, videoSourceImage.extent.width))
        radiusPixels /= 2
        radiusPixels *= cornerRadius
        roundedRectangleGenerator.radius = radiusPixels
        return roundedRectangleGenerator.outputImage
    }

    private func makeScale(
        _ videoSourceImage: CIImage,
        _ sceneWidget: SettingsSceneWidget,
        _ size: CGSize,
        _ mirror: Bool
    ) -> (Double, Double) {
        var scaleX = toPixels(sceneWidget.layout.size, size.width) / videoSourceImage.extent.size.width
        let scaleY = toPixels(sceneWidget.layout.size, size.height) / videoSourceImage.extent.size.height
        let scale = min(scaleX, scaleY)
        if mirror {
            scaleX = -1 * scale
        } else {
            scaleX = scale
        }
        return (scaleX, scale)
    }

    private func makeTranslation(
        _ videoSourceImage: CIImage,
        _ sceneWidget: SettingsSceneWidget,
        _ size: CGSize,
        _ scaleX: Double,
        _ scaleY: Double,
        _ mirror: Bool
    ) -> CGAffineTransform {
        var x = toPixels(sceneWidget.layout.x, size.width)
        if mirror {
            x -= videoSourceImage.extent.width * scaleX
        }
        let y = size.height - toPixels(sceneWidget.layout.y, size.height) - videoSourceImage.extent.height * scaleY
        return CGAffineTransform(translationX: x, y: y)
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
            roundedCornersBlender.maskImage = makeRoundedRectangleMask(image, settings.cornerRadius)
            return roundedCornersBlender.outputImage ?? image
        } else {
            let (borderWidth, scaleX, scaleY) = settings.borderWidthAndScale(image.extent)
            let borderImage = CIImage(color: settings.borderColor)
                .cropped(to: image.extent)
                .scaled(x: scaleX, y: scaleY)
                .translated(x: -borderWidth, y: -borderWidth)
            let roundedCornersBlender = CIFilter.blendWithMask()
            roundedCornersBlender.inputImage = borderImage
            roundedCornersBlender.maskImage = makeRoundedRectangleMask(borderImage, settings.cornerRadius)
            guard let roundedBorderImage = roundedCornersBlender.outputImage else {
                return image
            }
            roundedCornersBlender.inputImage = image
            roundedCornersBlender.maskImage = makeRoundedRectangleMask(image, settings.cornerRadius)
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
            return crop(image)
        } else {
            return image
        }
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        if settings.cornerRadius == 0 {
            return makeSharpCornersImage(image, settings)
        } else {
            return makeRoundedCornersImage(image, settings)
        }
    }
}
