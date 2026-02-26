import CoreImage

final class CameraManEffect: VideoEffect {
    static let movementDuration: Double = 1.5
    static let stillDuration: Double = 0.5

    private let maxSegmentIterations = 10_000
    private let minDuration: Double = 0.1
    private let minSpeedFactor: Double = 0.1
    private let speedOffsetSeed: Double = 2

    private var startTime: Double?
    private let minScale: Double = 0.92
    private let durationVariation: Double = 0.35
    private let speedVariation: Double = 0.3

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
        let segment = segmentInfo(elapsed: elapsed)
        let movementProgress = min(segment.elapsedInSegment / segment.movementDuration, 1)
        let progress = if movementProgress == 1 {
            1
        } else {
            min(movementProgress * segment.speedFactor, 1)
        }
        let easedProgress = smoothStep(progress)
        let fromX = position(Double(segment.index), offset: 0)
        let fromY = position(Double(segment.index), offset: 1)
        let toX = position(Double(segment.index + 1), offset: 0)
        let toY = position(Double(segment.index + 1), offset: 1)
        let fromScale = scale(Double(segment.index))
        let toScale = scale(Double(segment.index + 1))
        let x = fromX + (toX - fromX) * easedProgress
        let y = fromY + (toY - fromY) * easedProgress
        let cropScale = fromScale + (toScale - fromScale) * easedProgress
        let cropWidth = width * cropScale
        let cropHeight = height * cropScale
        let maxOffsetX = width - cropWidth
        let maxOffsetY = height - cropHeight
        return CGRect(x: maxOffsetX * x, y: maxOffsetY * y, width: cropWidth, height: cropHeight)
    }

    internal func segmentInfo(elapsed: Double) -> (index: Int,
                                                   elapsedInSegment: Double,
                                                   movementDuration: Double,
                                                   stillDuration: Double,
                                                   speedFactor: Double)
    {
        var index = 0
        var elapsedInSegment = max(elapsed, 0)
        while index < maxSegmentIterations {
            let movementDuration = duration(index: index, base: Self.movementDuration, offset: 0)
            let stillDuration = duration(index: index, base: Self.stillDuration, offset: 1)
            let segmentDuration = movementDuration + stillDuration
            if elapsedInSegment <= segmentDuration {
                return (index: index,
                        elapsedInSegment: elapsedInSegment,
                        movementDuration: movementDuration,
                        stillDuration: stillDuration,
                        speedFactor: speed(index: index))
            }
            elapsedInSegment -= segmentDuration
            index += 1
        }
        let movementDuration = duration(index: 0, base: Self.movementDuration, offset: 0)
        let stillDuration = duration(index: 0, base: Self.stillDuration, offset: 1)
        return (index: 0,
                elapsedInSegment: 0,
                movementDuration: movementDuration,
                stillDuration: stillDuration,
                speedFactor: speed(index: 0))
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

    private func duration(index: Int, base: Double, offset: Double) -> Double {
        return max(minDuration, base * randomFactor(index: index, offset: offset, variation: durationVariation))
    }

    private func speed(index: Int) -> Double {
        return max(minSpeedFactor,
                   randomFactor(index: index, offset: speedOffsetSeed, variation: speedVariation))
    }

    private func randomFactor(index: Int, offset: Double, variation: Double) -> Double {
        return 1 + (position(Double(index), offset: offset + 10) * 2 - 1) * variation
    }
}
