import AVFoundation
import MetalPetal
import Vision

final class VideoSourceEffect: VideoEffect {
    private var videoSourceId: UUID = .init()
    private var sceneWidget: Atomic<SettingsSceneWidget?> = .init(nil)
    private var radius: Atomic<Float> = .init(0)

    override func getName() -> String {
        return "video source"
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget?) {
        self.sceneWidget.mutate { $0 = sceneWidget }
    }

    func setRadius(radius: Float) {
        self.radius.mutate { $0 = radius }
    }

    override func execute(_ backgroundImage: CIImage, _ info: VideoEffectInfo) -> CIImage {
        guard let sceneWidget = sceneWidget.value else {
            return backgroundImage
        }
        let radius = self.radius.value
        guard var videoSourceImage = info.videoUnit.getCIImage(videoSourceId, info.presentationTimeStamp)
        else {
            return backgroundImage
        }
        let size = backgroundImage.extent.size
        let scaleX = toPixels(sceneWidget.width, size.width) / videoSourceImage.extent.size.width
        let scaleY = toPixels(sceneWidget.height, size.height) / videoSourceImage.extent.size.height
        let scale = min(scaleX, scaleY)
        let x = toPixels(sceneWidget.x, size.width)
        let y = size.height - toPixels(sceneWidget.y, size.height) - videoSourceImage.extent.height * scale
        if radius == 0 {
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
            radiusPixels *= radius
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
