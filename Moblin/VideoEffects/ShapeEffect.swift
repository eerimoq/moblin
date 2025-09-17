import AVFoundation
import MetalPetal
import Vision

struct ShapeEffectSettings {
    var cornerRadius: Float = 0
    var borderWidth: Double = 1.0
    var borderColor: CIColor = .black

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
        var scaleX = toPixels(sceneWidget.size, size.width) / videoSourceImage.extent.size.width
        let scaleY = toPixels(sceneWidget.size, size.height) / videoSourceImage.extent.size.height
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
        var x = toPixels(sceneWidget.x, size.width)
        if mirror {
            x -= videoSourceImage.extent.width * scaleX
        }
        let y = size.height - toPixels(sceneWidget.y, size.height) - videoSourceImage.extent.height * scaleY
        return CGAffineTransform(translationX: x, y: y)
    }

    private func makeSharpCornersImage(_ image: CIImage, _ settings: ShapeEffectSettings) -> CIImage {
        if settings.borderWidth == 0 {
            return image
        } else {
            let (width, scaleX, scaleY) = settings.borderWidthAndScale(image.extent)
            let borderImage = CIImage(color: settings.borderColor)
                .cropped(to: image.extent)
                .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
                .transformed(by: CGAffineTransform(translationX: -1 * width, y: -width))
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
            let (width, scaleX, scaleY) = settings.borderWidthAndScale(image.extent)
            let borderImage = CIImage(color: settings.borderColor).cropped(to: image.extent)
                .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
                .transformed(by: CGAffineTransform(translationX: -1.0 * width, y: -width))
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

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        if settings.cornerRadius == 0 {
            return makeSharpCornersImage(image, settings)
        } else {
            return makeRoundedCornersImage(image, settings)
        }
    }
}
