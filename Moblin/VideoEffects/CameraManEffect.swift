import CoreImage

final class CameraManEffect: VideoEffect {
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

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        let width = image.extent.width
        let height = image.extent.height
        let now = info.presentationTimeStamp.seconds
        if startTime == nil {
            startTime = now
        }
        let elapsed = now - startTime!
        let scale = minScale + (1 - minScale) * (0.5 + 0.5 * cos(elapsed * zoomSpeed * speed))
        let isRising = scale - previousScale > 0
        if previousIsRising && !isRising {
            isStill.toggle()
        }
        previousScale = scale
        previousIsRising = isRising
        if isStill, !alwaysMove {
            return image
        }
        let cropWidth = width * scale
        let cropHeight = height * scale
        let maxOffsetX = width - cropWidth
        let maxOffsetY = height - cropHeight
        let cropX = maxOffsetX * (0.5 + 0.5 * sin(elapsed * xSpeed * speed))
        let cropY = maxOffsetY * (0.5 + (moveVertically ? 0.5 * cos(elapsed * ySpeed * speed) : 0))
        let cropRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
        let scaleX = width / cropWidth
        let scaleY = height / cropHeight
        return image
            .cropped(to: cropRect)
            .transformed(by: CGAffineTransform(translationX: -cropX, y: -cropY))
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
    }
}
