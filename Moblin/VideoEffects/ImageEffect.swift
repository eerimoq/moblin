import AVFoundation
import MetalPetal
import UIKit
import Vision

final class ImageEffect: VideoEffect {
    private let filter = CIFilter.sourceOverCompositing()
    private var extent = CGRect.zero {
        didSet {
            guard extent != oldValue else {
                return
            }
            prepare(size: extent.size)
            prepareMetalPetal(size: extent.size)
        }
    }

    private var overlay: CIImage?
    private var overlayMetalPetal: MTIImage?
    private let originalImage: UIImage
    private var sceneWidget: SettingsSceneWidget?
    private let settingName: String
    let widgetId: UUID

    init(image: UIImage, settingName: String, widgetId: UUID) {
        originalImage = image
        self.settingName = settingName
        self.widgetId = widgetId
        super.init()
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget) {
        mixerLockQueue.async {
            if self.sceneWidget?.isSamePositioning(other: sceneWidget) != true {
                self.sceneWidget = sceneWidget
                self.prepare(size: self.extent.size)
                self.prepareMetalPetal(size: self.extent.size)
            }
        }
    }

    override func getName() -> String {
        return "\(settingName) image widget"
    }

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        extent = image.extent
        if let overlay {
            filter.inputImage = applyEffects(overlay, info)
        } else {
            filter.inputImage = nil
        }
        filter.backgroundImage = image
        return filter.outputImage ?? image
    }

    override func executeMetalPetal(_ image: MTIImage?, _: VideoEffectInfo) -> MTIImage? {
        guard let image, let sceneWidget else {
            return image
        }
        extent = image.extent
        guard let overlayMetalPetal else {
            return image
        }
        let x = toPixels(sceneWidget.x, extent.size.width) + overlayMetalPetal.size.width / 2
        let y = toPixels(sceneWidget.y, extent.size.height) + overlayMetalPetal.size.height / 2
        let filter = MTIMultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.layers = [
            .init(content: overlayMetalPetal, position: .init(x: x, y: y)),
        ]
        return filter.outputImage ?? image
    }

    private func prepare(size: CGSize) {
        guard let sceneWidget, size != .zero else {
            return
        }
        UIGraphicsBeginImageContext(size)
        let x = toPixels(sceneWidget.x, size.width)
        let y = toPixels(sceneWidget.y, size.height)
        let width = toPixels(sceneWidget.width, size.width)
        let height = toPixels(sceneWidget.height, size.height)
        let image = originalImage.scalePreservingAspectRatio(targetSize: CGSize(
            width: width,
            height: height
        ))
        image.draw(at: CGPoint(x: x, y: y))
        overlay = CIImage(
            image: UIGraphicsGetImageFromCurrentImageContext()!,
            options: nil
        )
        UIGraphicsEndImageContext()
    }

    private func prepareMetalPetal(size: CGSize) {
        guard let originalImage = originalImage.cgImage, let sceneWidget, size != .zero else {
            return
        }
        let width = toPixels(sceneWidget.width, size.width)
        let height = toPixels(sceneWidget.height, size.height)
        overlayMetalPetal = MTIImage(cgImage: originalImage, isOpaque: true).resized(
            to: .init(width: width, height: height),
            resizingMode: .aspect
        )
    }
}
