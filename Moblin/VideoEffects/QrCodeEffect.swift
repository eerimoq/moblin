import AVFoundation
import CoreImage
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
        return applyEffectsResizeMirrorMove(qrCodeImage, newSceneWidget, false, image.extent, info)
            .composited(over: image)
    }

    private func update(newSceneWidget: SettingsSceneWidget, size: CGSize) {
        guard newSceneWidget.layout.extent() != sceneWidget?.layout.extent() || size != self.size else {
            return
        }
        guard let data = widget.message.data(using: .utf8) else {
            return
        }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
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
