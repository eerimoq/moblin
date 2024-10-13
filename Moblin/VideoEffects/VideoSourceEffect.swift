import AVFoundation
import MetalPetal
import Vision

final class VideoSourceEffect: VideoEffect {
    private var videoSourceId: UUID = .init()
    private var sceneWidget: Atomic<SettingsSceneWidget?> = .init(nil)

    override func getName() -> String {
        return "video source"
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget?) {
        self.sceneWidget.mutate { $0 = sceneWidget }
    }

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        guard let sceneWidget = sceneWidget.value else {
            return image
        }
        guard let outputImage = info.videoUnit.getCIImage(videoSourceId, info.presentationTimeStamp) else {
            return image
        }
        let size = image.extent.size
        let scaleX = toPixels(sceneWidget.width, size.width) / outputImage.extent.size.width
        let scaleY = toPixels(sceneWidget.height, size.height) / outputImage.extent.size.height
        let scale = min(scaleX, scaleY)
        let x = toPixels(sceneWidget.x, size.width)
        let y = size.height - toPixels(sceneWidget.y, size.height) - outputImage.extent.height * scale
        return outputImage
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: x, y: y))
            .cropped(to: .init(x: 0, y: 0, width: size.width, height: size.height))
            .composited(over: image)
    }

    override func executeMetalPetal(_ image: MTIImage?, _: VideoEffectInfo) -> MTIImage? {
        return image
    }
}
