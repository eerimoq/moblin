import AVFoundation
import MetalPetal
import Vision

private let qrCodeQueue = DispatchQueue(label: "com.eerimoq.widget.qr-code")

final class QrCodeEffect: VideoEffect {
    private let filter = CIFilter.sourceOverCompositing()
    private let widget: SettingsWidgetQrCode
    private var sceneWidget: SettingsSceneWidget?
    private var image: CIImage?
    private var imageMetalPetal: MTIImage?

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
        // guard let cgImage = outputImage.cgImage else {
        //     return
        // }
        // let imageMetalPetal = MTIImage(cgImage: cgImage, isOpaque: false).resized(
        //     to: .init(width: toPixels(sceneWidget.width, size.width), height: toPixels(sceneWidget.height, size.height)),
        //     resizingMode: .aspect
        // )
        qrCodeQueue.sync {
            self.image = image
            // self.imageMetalPetal = imageMetalPetal
            self.sceneWidget = sceneWidget
        }
    }

    override func execute(_ image: CIImage, _: [VNFaceObservation]?, _: Bool) -> CIImage {
        filter.inputImage = qrCodeQueue.sync { self.image }
        filter.backgroundImage = image
        return filter.outputImage ?? image
    }

    override func executeMetalPetal(_ image: MTIImage?, _: [VNFaceObservation]?, _: Bool) -> MTIImage? {
        guard let image, let imageMetalPetal else {
            return image
        }
        let (overlay, sceneWidget) = qrCodeQueue.sync {
            (self.imageMetalPetal, self.sceneWidget)
        }
        guard let overlay, let sceneWidget else {
            return image
        }
        let x = toPixels(sceneWidget.x, image.extent.size.width) + overlay.size.width / 2
        let y = toPixels(sceneWidget.y, image.extent.size.height) + overlay.size.height / 2
        let filter = MTIMultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.layers = [
            .init(content: overlay, position: .init(x: x, y: y)),
            .init(content: overlay, position: .init(x: x, y: y)),
        ]
        return filter.outputImage ?? image
    }
}
