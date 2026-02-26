import CoreImage

final class CameraManEffect: VideoEffect {
    static let movementDuration: Double = 3
    static let stillDuration: Double = 1

    private var startTime: Double?
    private let minScale: Double = 0.92

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        let width = image.extent.width
        let height = image.extent.height
        let now = info.presentationTimeStamp.seconds
        if startTime == nil {
            startTime = now
        }
        let cropRect = cropRect(width: width, height: height, elapsed: now - startTime!)
        let scaleX = width / cropRect.width
        let scaleY = height / cropRect.height
        return image
            .cropped(to: cropRect)
            .transformed(by: CGAffineTransform(translationX: -cropRect.minX, y: -cropRect.minY))
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
    }

    internal func cropRect(width: CGFloat, height: CGFloat, elapsed: Double) -> CGRect {
        let segmentDuration = Self.movementDuration + Self.stillDuration
        let segment = floor(elapsed / segmentDuration)
        let segmentElapsed = elapsed.truncatingRemainder(dividingBy: segmentDuration)
        let progress = min(segmentElapsed / Self.movementDuration, 1)
        let easedProgress = smoothStep(progress)
        let fromX = position(segment, offset: 0)
        let fromY = position(segment, offset: 1)
        let toX = position(segment + 1, offset: 0)
        let toY = position(segment + 1, offset: 1)
        let fromScale = scale(segment)
        let toScale = scale(segment + 1)
        let x = fromX + (toX - fromX) * easedProgress
        let y = fromY + (toY - fromY) * easedProgress
        let cropScale = fromScale + (toScale - fromScale) * easedProgress
        let cropWidth = width * cropScale
        let cropHeight = height * cropScale
        let maxOffsetX = width - cropWidth
        let maxOffsetY = height - cropHeight
        return CGRect(x: maxOffsetX * x, y: maxOffsetY * y, width: cropWidth, height: cropHeight)
    }

    private func smoothStep(_ value: Double) -> Double {
        return value * value * (3 - 2 * value)
    }

    private func scale(_ index: Double) -> Double {
        return minScale + (1 - minScale) * position(index, offset: 2)
    }

    private func position(_ index: Double, offset: Double) -> Double {
        return 0.5 + 0.5 * sin(index * 8.231 + offset * 5.197)
    }
}
