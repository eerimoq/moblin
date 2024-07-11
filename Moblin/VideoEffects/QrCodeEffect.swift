import AVFoundation
import MetalPetal
import Vision

private let qrCodeQueue = DispatchQueue(label: "com.eerimoq.widget.qr-code")

final class QrCodeEffect: VideoEffect {
    private let filter = CIFilter.sourceOverCompositing()
    private let widget: SettingsWidgetQrCode
    private var image: CIImage?

    init(widget: SettingsWidgetQrCode) {
        self.widget = widget
        super.init()
    }

    override func getName() -> String {
        return "QR code widget"
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget?, size: CGSize?) {
        guard let sceneWidget, let size else {
            return
        }
        let data = widget.message.data(using: String.Encoding.ascii)
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data!
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else {
            return
        }
        let x = toPixels(sceneWidget.x, size.width)
        let y = size.height - toPixels(sceneWidget.y + sceneWidget.height, size.height)
        let scaleX = toPixels(sceneWidget.width, size.width) / outputImage.extent.size.width
        let scaleY = toPixels(sceneWidget.height, size.height) / outputImage.extent.size.height
        let scale = min(scaleX, scaleY)
        let image = outputImage
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: x, y: y))
            .cropped(to: .init(x: 0, y: 0, width: size.width, height: size.height))
        qrCodeQueue.sync {
            self.image = image
        }
    }

    override func execute(_ image: CIImage, _: [VNFaceObservation]?, _: Bool) -> CIImage {
        filter.inputImage = qrCodeQueue.sync { self.image }
        filter.backgroundImage = image
        return filter.outputImage ?? image
    }

    override func executeMetalPetal(_ image: MTIImage?, _: [VNFaceObservation]?, _: Bool) -> MTIImage? {
        return image
    }
}
