import AVFoundation
import MetalPetal
import Vision

final class QrCodeEffect: VideoEffect {
    private let widget: SettingsWidgetQrCode
    private var newSceneWidget: SettingsSceneWidget?
    private var sceneWidget: SettingsSceneWidget?
    private var size: CGSize = .zero
    private var qrCodeImage: CIImage?

    init(widget: SettingsWidgetQrCode) {
        self.widget = widget
        super.init()
    }

    override func getName() -> String {
        return "QR code widget"
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget) {
        processorPipelineQueue.async {
            self.newSceneWidget = sceneWidget
        }
    }

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        guard let newSceneWidget else {
            return image
        }
        update(newSceneWidget: newSceneWidget, size: image.extent.size)
        guard let qrCodeImage else {
            return image
        }
        let resizedImage = qrCodeImage.resizeMirror(newSceneWidget, image.extent.size, false)
        return applyEffects(resizedImage, info)
            .move(newSceneWidget, image.extent.size)
            .cropped(to: image.extent)
            .composited(over: image)
    }

    private func update(newSceneWidget: SettingsSceneWidget, size: CGSize) {
        guard newSceneWidget.extent() != sceneWidget?.extent() || size != self.size else {
            return
        }
        let data = widget.message.data(using: String.Encoding.ascii)
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data!
        filter.correctionLevel = "M"
        sceneWidget = newSceneWidget
        self.size = size
        guard let image = filter.outputImage else {
            return
        }
        let scale = 400 / image.extent.size.width
        qrCodeImage = image.scaled(x: scale, y: scale)
    }
}
