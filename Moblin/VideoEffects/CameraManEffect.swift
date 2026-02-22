import CoreImage

final class CameraManEffect: VideoEffect {
    private var startTime: Double?
    private let minScale: Double = 0.92
    private let xSpeed: Double = 0.27
    private let ySpeed: Double = 0.36
    private let zoomSpeed: Double = 0.33

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        let width = image.extent.width
        let height = image.extent.height
        let now = info.presentationTimeStamp.seconds
        if startTime == nil {
            startTime = now
        }
        let elapsed = now - startTime!
        let scale = minScale + (1 - minScale) * (0.5 + 0.5 * cos(elapsed * zoomSpeed))
        let cropWidth = width * scale
        let cropHeight = height * scale
        let maxOffsetX = width - cropWidth
        let maxOffsetY = height - cropHeight
        let cropX = maxOffsetX * (0.5 + 0.5 * sin(elapsed * xSpeed))
        let cropY = maxOffsetY * (0.5 + 0.5 * cos(elapsed * ySpeed))
        let cropRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
        let scaleX = width / cropWidth
        let scaleY = height / cropHeight
        return image
            .cropped(to: cropRect)
            .transformed(by: CGAffineTransform(translationX: -cropX, y: -cropY))
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
    }
}
