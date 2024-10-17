import AVFoundation
import MetalPetal
import Vision

struct VideoSourceEffectSettings {
    var cornerRadius: Float = 0
    var cropEnabled: Bool = false
    var cropX: Double = 0
    var cropY: Double = 0
    var cropWidth: Double = 1
    var cropHeight: Double = 1
    var rotation: Double = 0
}

final class VideoSourceEffect: VideoEffect {
    private var videoSourceId: Atomic<UUID> = .init(.init())
    private var sceneWidget: Atomic<SettingsSceneWidget?> = .init(nil)
    private var settings: Atomic<VideoSourceEffectSettings> = .init(.init())

    override func getName() -> String {
        return "video source"
    }

    func setVideoSourceId(videoSourceId: UUID) {
        self.videoSourceId.mutate { $0 = videoSourceId }
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget?) {
        self.sceneWidget.mutate { $0 = sceneWidget }
    }

    func setSettings(settings: VideoSourceEffectSettings) {
        self.settings.mutate { $0 = settings }
    }

    private func crop(_ videoSourceImage: CIImage, _ settings: VideoSourceEffectSettings) -> CIImage {
        let cropX = toPixels(100 * settings.cropX, videoSourceImage.extent.width)
        let cropY = toPixels(100 * settings.cropY, videoSourceImage.extent.height)
        let cropWidth = toPixels(100 * settings.cropWidth, videoSourceImage.extent.width)
        let cropHeight = toPixels(100 * settings.cropHeight, videoSourceImage.extent.height)
        return videoSourceImage
            .cropped(to: .init(
                x: cropX,
                y: videoSourceImage.extent.height - cropY - cropHeight,
                width: cropWidth,
                height: cropHeight
            ))
            .transformed(by: CGAffineTransform(
                translationX: -cropX,
                y: -(videoSourceImage.extent.height - cropY - cropHeight)
            ))
    }

    private func rotate(_ videoSourceImage: CIImage, _ settings: VideoSourceEffectSettings) -> CIImage {
        var rotation = 0.0
        if videoSourceImage.extent.height > videoSourceImage.extent.width {
            rotation = -90
        }
        rotation += settings.rotation
        if rotation == -90 {
            rotation = 270
        }
        switch rotation {
        case 90:
            return videoSourceImage.oriented(.right)
        case 180:
            return videoSourceImage.oriented(.down)
        case 270:
            return videoSourceImage.oriented(.left)
        default:
            return videoSourceImage
        }
    }

    override func execute(_ backgroundImage: CIImage, _ info: VideoEffectInfo) -> CIImage {
        guard let sceneWidget = sceneWidget.value else {
            return backgroundImage
        }
        let settings = self.settings.value
        guard var videoSourceImage = info.videoUnit.getCIImage(
            videoSourceId.value,
            info.presentationTimeStamp
        )
        else {
            return backgroundImage
        }
        videoSourceImage = rotate(videoSourceImage, settings)
        if settings.cropEnabled {
            videoSourceImage = crop(videoSourceImage, settings)
        }
        let size = backgroundImage.extent.size
        let scaleX = toPixels(sceneWidget.width, size.width) / videoSourceImage.extent.size.width
        let scaleY = toPixels(sceneWidget.height, size.height) / videoSourceImage.extent.size.height
        let scale = min(scaleX, scaleY)
        let x = toPixels(sceneWidget.x, size.width)
        let y = size.height - toPixels(sceneWidget.y, size.height) - videoSourceImage.extent.height * scale
        if settings.cornerRadius == 0 {
            return videoSourceImage
                .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                .transformed(by: CGAffineTransform(translationX: x, y: y))
                .cropped(to: .init(x: 0, y: 0, width: size.width, height: size.height))
                .composited(over: backgroundImage)
        } else {
            let clearBackgroundImage = CIImage.clear.cropped(to: backgroundImage.extent)
            videoSourceImage = videoSourceImage
                .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            let roundedRectangleGenerator = CIFilter.roundedRectangleGenerator()
            roundedRectangleGenerator.color = .green
            roundedRectangleGenerator.extent = videoSourceImage.extent
            var radiusPixels = Float(min(videoSourceImage.extent.height, videoSourceImage.extent.width))
            radiusPixels /= 2
            radiusPixels *= settings.cornerRadius
            roundedRectangleGenerator.radius = radiusPixels
            guard var roundedRectangleMask = roundedRectangleGenerator.outputImage else {
                return backgroundImage
            }
            videoSourceImage = videoSourceImage
                .transformed(by: CGAffineTransform(translationX: x, y: y))
                .cropped(to: .init(x: 0, y: 0, width: size.width, height: size.height))
                .composited(over: clearBackgroundImage)
            roundedRectangleMask = roundedRectangleMask
                .transformed(by: CGAffineTransform(translationX: x, y: y))
                .cropped(to: .init(x: 0, y: 0, width: size.width, height: size.height))
                .composited(over: clearBackgroundImage)
            let roundedCornersBlender = CIFilter.blendWithMask()
            roundedCornersBlender.inputImage = videoSourceImage
            roundedCornersBlender.backgroundImage = backgroundImage
            roundedCornersBlender.maskImage = roundedRectangleMask
            return roundedCornersBlender.outputImage ?? backgroundImage
        }
    }

    override func executeMetalPetal(_ image: MTIImage?, _: VideoEffectInfo) -> MTIImage? {
        return image
    }
}
