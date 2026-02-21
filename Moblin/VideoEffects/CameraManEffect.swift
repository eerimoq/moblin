import AVFoundation
import UIKit
import Vision

final class CameraManEffect: VideoEffect {
    private var startTime: Double?
    private let minScale: Double = 0.80
    private let maxScale: Double = 0.95
    private let xSpeed: Double = 0.07
    private let ySpeed: Double = 0.11
    private let zoomSpeed: Double = 0.13

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        let width = image.extent.width
        let height = image.extent.height
        let now = info.presentationTimeStamp.seconds
        if startTime == nil {
            startTime = now
        }
        guard let startTime else {
            return image
        }
        let elapsed = now - startTime
        let scale = minScale + (maxScale - minScale) * (0.5 + 0.5 * sin(elapsed * zoomSpeed))
        let cropWidth = width * scale
        let cropHeight = height * scale
        let maxOffsetX = width - cropWidth
        let maxOffsetY = height - cropHeight
        let cropX = maxOffsetX * (0.5 + 0.5 * sin(elapsed * xSpeed))
        let cropY = maxOffsetY * (0.5 + 0.5 * cos(elapsed * ySpeed))
        let cropRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
        let cropped = image.cropped(to: cropRect)
        let scaleX = width / cropWidth
        let scaleY = height / cropHeight
        return cropped
            .transformed(by: CGAffineTransform(translationX: -cropX, y: -cropY))
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
    }
}
