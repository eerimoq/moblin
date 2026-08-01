import CoreImage
import MetalPetal

final class CameraManEffect: VideoEffect, @unchecked Sendable {
    private var startTime: Double?
    private let minScale: Double = 0.92
    private let xSpeed: Double = 0.27
    private let ySpeed: Double = 0.36
    private let zoomSpeed: Double = 0.33
    private var moveVertically: Bool
    private var speed: Double
    private var alwaysMove: Bool
    private var previousIsRising: Bool = false
    private var previousScale: Double = 0
    private var isStill: Bool = true

    init(moveVertically: Bool, speed: Double, alwaysMove: Bool) {
        self.moveVertically = moveVertically
        self.speed = speed
        self.alwaysMove = alwaysMove
    }

    func setSettings(moveVertically: Bool, speed: Double, alwaysMove: Bool) {
        processorPipelineQueue.async {
            self.moveVertically = moveVertically
            self.speed = speed
            self.alwaysMove = alwaysMove
        }
    }

    private func calcCropRegion(_ size: CGSize, _ presentationTimeStamp: Double) -> CGRect? {
        if startTime == nil {
            startTime = presentationTimeStamp
        }
        let elapsed = presentationTimeStamp - startTime!
        let scale = minScale + (1 - minScale) * (0.5 + 0.5 * cos(elapsed * zoomSpeed * speed))
        let isRising = scale - previousScale > 0
        if previousIsRising, !isRising {
            isStill.toggle()
        }
        previousScale = scale
        previousIsRising = isRising
        if isStill, !alwaysMove {
            return nil
        }
        let cropWidth = size.width * scale
        let cropHeight = size.height * scale
        let maxOffsetX = size.width - cropWidth
        let maxOffsetY = size.height - cropHeight
        let cropX = maxOffsetX * (0.5 + 0.5 * sin(elapsed * xSpeed * speed))
        let cropY = maxOffsetY * (0.5 + (moveVertically ? 0.5 * cos(elapsed * ySpeed * speed) : 0))
        return CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
    }

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        guard let cropRect = calcCropRegion(image.extent.size, info.presentationTimeStamp.seconds) else {
            return image
        }
        let scaleX = image.extent.width / cropRect.width
        let scaleY = image.extent.height / cropRect.height
        return image
            .cropped(to: cropRect)
            .transformed(by: CGAffineTransform(translationX: -cropRect.minX, y: -cropRect.minY))
            .transformed(
                by: CGAffineTransform(scaleX: scaleX, y: scaleY),
                highQualityDownsample: highQualityDownsampling
            )
    }

    override func executeMetalPetal(_ image: MTIImage, _ info: VideoEffectInfo) -> MTIImage {
        let size = image.extent.size
        guard let cropRect = calcCropRegion(size, info.presentationTimeStamp.seconds) else {
            return image
        }
        let contentRegion = CGRect(x: cropRect.minX,
                                   y: size.height - cropRect.maxY,
                                   width: cropRect.width,
                                   height: cropRect.height)
        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.layers = [
            .content(image, modifier: { layer in
                layer.contentRegion = contentRegion
                layer.size = size
                layer.position = CGPoint(x: size.width / 2, y: size.height / 2)
            }),
        ]
        return filter.outputImage ?? image
    }
}
