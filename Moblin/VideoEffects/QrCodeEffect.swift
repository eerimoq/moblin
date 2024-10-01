import AVFoundation
import MetalPetal
import Vision

private let qrCodeQueue = DispatchQueue(label: "com.eerimoq.widget.qr-code")

final class QrCodeEffect: VideoEffect {
    private let filter = CIFilter.sourceOverCompositing()
    private let widget: SettingsWidgetQrCode
    private var newSceneWidget: SettingsSceneWidget?
    private var sceneWidget: SettingsSceneWidget?
    private var size: CGSize = .zero
    private var image: CIImage?
    private var sceneWidgetMetalPetal: SettingsSceneWidget?
    private var sizeMetalPetal: CGSize = .zero
    private var imageMetalPetal: MTIImage?

    init(widget: SettingsWidgetQrCode) {
        self.widget = widget
        super.init()
    }

    override func getName() -> String {
        return "QR code widget"
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget?) {
        qrCodeQueue.sync {
            self.newSceneWidget = sceneWidget?.clone()
        }
    }

    private func update(size: CGSize) {
        let newSceneWidget = qrCodeQueue.sync {
            self.newSceneWidget
        }
        guard let newSceneWidget else {
            return
        }
        guard newSceneWidget.extent() != sceneWidget?.extent() || size != self.size else {
            return
        }
        let data = widget.message.data(using: String.Encoding.ascii)
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data!
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else {
            return
        }
        let x = toPixels(newSceneWidget.x, size.width)
        let y = size.height - toPixels(newSceneWidget.y + newSceneWidget.height, size.height)
        let scaleX = toPixels(newSceneWidget.width, size.width) / outputImage.extent.size.width
        let scaleY = toPixels(newSceneWidget.height, size.height) / outputImage.extent.size.height
        let scale = min(scaleX, scaleY)
        image = outputImage
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: x, y: y))
            .cropped(to: .init(x: 0, y: 0, width: size.width, height: size.height))
        sceneWidget = newSceneWidget
        self.size = size
    }

    private func updateMetalPetal(size: CGSize) {
        let newSceneWidget = qrCodeQueue.sync {
            self.newSceneWidget
        }
        guard let newSceneWidget else {
            return
        }
        guard newSceneWidget.extent() != sceneWidgetMetalPetal?.extent() || size != sizeMetalPetal else {
            return
        }
        // let data = widget.message.data(using: String.Encoding.ascii)
        // let filter = CIFilter.qrCodeGenerator()
        // filter.message = data!
        // filter.correctionLevel = "M"
        // let cgImage = context.createCGImage(filter.outputImage, from: image.extent)
        // guard let outputImage = filter.outputImage?.cgImage else {
        //     return
        // }
        // imageMetalPetal = MTIImage(cgImage: outputImage, isOpaque: false).resized(
        //     to: .init(width: toPixels(newSceneWidget.width, size.width),
        //               height: toPixels(newSceneWidget.height, size.height)),
        //     resizingMode: .aspect
        // )
        sceneWidgetMetalPetal = newSceneWidget
        sizeMetalPetal = size
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        update(size: image.extent.size)
        filter.inputImage = self.image
        filter.backgroundImage = image
        return filter.outputImage ?? image
    }

    override func executeMetalPetal(_ image: MTIImage?, _: VideoEffectInfo) -> MTIImage? {
        guard let image else {
            return image
        }
        updateMetalPetal(size: image.size)
        guard let imageMetalPetal, let sceneWidget else {
            return image
        }
        let x = toPixels(sceneWidget.x, image.extent.size.width) + imageMetalPetal.size.width / 2
        let y = toPixels(sceneWidget.y, image.extent.size.height) + imageMetalPetal.size.height / 2
        let filter = MTIMultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.layers = [
            .init(content: imageMetalPetal, position: .init(x: x, y: y)),
            .init(content: imageMetalPetal, position: .init(x: x, y: y)),
        ]
        return filter.outputImage ?? image
    }
}
