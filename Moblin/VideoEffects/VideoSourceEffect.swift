import AVFoundation
import CoreImage
import Vision

struct VideoSourceEffectSettings {
    var rotation: Double = 0
    var trackFaceEnabled: Bool = false
    var trackFaceZoom: Double = 2.2
    var mirror: Bool = false
}

class PositionInterpolator {
    private(set) var current: Double?
    private var delta = 0.0
    var target: Double?

    func update(timeElapsed: Double) -> Double {
        if let current, let target {
            delta = 0.8 * delta + 0.2 * (target - current)
            if abs(delta) > 5 {
                self.current = current + delta * 2 * timeElapsed
            }
        } else if let target {
            current = target
        } else {
            current = 0
        }
        return current!
    }
}

final class VideoSourceEffect: VideoEffect {
    private var videoSourceId: UUID = .init()
    private var sceneWidget: SettingsSceneWidget?
    private var settings: VideoSourceEffectSettings = .init()
    private let trackFaceLeft = PositionInterpolator()
    private let trackFaceRight = PositionInterpolator()
    private let trackFaceTop = PositionInterpolator()
    private let trackFaceBottom = PositionInterpolator()
    private var trackFacePresentationTimeStamp = 0.0
    private var trackFaceNeedsDetectionsPresentationTimeStamp = 0.0

    override func getName() -> String {
        return "Video source"
    }

    override func needsFaceDetections(_: Double) -> (Bool, UUID?, Double?) {
        if settings.trackFaceEnabled {
            return (false, videoSourceId, 0.5)
        } else {
            return (false, nil, nil)
        }
    }

    func setVideoSourceId(videoSourceId: UUID) {
        processorPipelineQueue.async {
            self.videoSourceId = videoSourceId
        }
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget) {
        processorPipelineQueue.async {
            self.sceneWidget = sceneWidget
        }
    }

    func setSettings(settings: VideoSourceEffectSettings) {
        processorPipelineQueue.async {
            self.settings = settings
        }
    }

    private func shouldUseFace(_ boundingBox: CGRect,
                               _ biggestBoundingBox: CGRect,
                               _ videoSourceImageSize: CGSize) -> Bool
    {
        if boundingBox.height < videoSourceImageSize.height / 10 {
            return false
        } else if boundingBox.height < biggestBoundingBox.height / 2 {
            return false
        } else {
            return true
        }
    }

    private func cropFace(
        _ videoSourceImage: CIImage,
        _ faceDetections: [VNFaceObservation]?,
        _ presentationTimeStamp: Double,
        _ zoom: Double
    ) -> CIImage {
        let videoSourceImageSize = videoSourceImage.extent.size
        var left = videoSourceImageSize.width
        var right = 0.0
        var top = 0.0
        var bottom = videoSourceImageSize.height
        if let faceDetections,
           let biggestBoundingBox = faceDetections.first?.stableBoundingBox(imageSize: videoSourceImageSize)
        {
            var anyFaceUsed = false
            for faceDetection in faceDetections {
                guard let boundingBox = faceDetection.stableBoundingBox(imageSize: videoSourceImageSize) else {
                    continue
                }
                guard shouldUseFace(boundingBox, biggestBoundingBox, videoSourceImageSize) else {
                    continue
                }
                left = min(left, boundingBox.minX)
                right = max(right, boundingBox.maxX)
                top = max(top, boundingBox.maxY)
                bottom = min(bottom, boundingBox.minY)
                anyFaceUsed = true
            }
            if anyFaceUsed {
                trackFaceLeft.target = left
                trackFaceRight.target = right
                trackFaceTop.target = top
                trackFaceBottom.target = bottom
            }
        }
        if trackFaceLeft.target == nil {
            trackFaceLeft.target = videoSourceImageSize.width * 0.33
            trackFaceRight.target = videoSourceImageSize.width * 0.67
            trackFaceTop.target = videoSourceImageSize.height * 0.67
            trackFaceBottom.target = videoSourceImageSize.height * 0.33
        }
        let timeElapsed = presentationTimeStamp - trackFacePresentationTimeStamp
        trackFacePresentationTimeStamp = presentationTimeStamp
        left = trackFaceLeft.update(timeElapsed: timeElapsed)
        right = trackFaceRight.update(timeElapsed: timeElapsed)
        top = trackFaceTop.update(timeElapsed: timeElapsed)
        bottom = trackFaceBottom.update(timeElapsed: timeElapsed)
        let width = (right - left) * zoom
        let height = (top - bottom) * zoom
        let centerX = (right + left) / 2
        let centerY = (top + bottom) / 2 * 1.05
        let side = max(width, height)
        let cropWidth = min(side, videoSourceImageSize.width)
        let cropHeight = min(side, videoSourceImageSize.height)
        let cropSquareSize = min(cropWidth, cropHeight).rounded(.down)
        var cropX = max(centerX - cropSquareSize / 2, 0)
        var cropY = max(videoSourceImageSize.height - centerY - cropSquareSize / 2, 0)
        cropX = min(cropX, videoSourceImageSize.width - cropSquareSize)
        cropY = min(cropY, videoSourceImageSize.height - cropSquareSize)
        return videoSourceImage
            .cropped(to: .init(
                x: cropX,
                y: videoSourceImageSize.height - cropY - cropSquareSize,
                width: cropSquareSize,
                height: cropSquareSize
            ))
            .translated(x: -cropX, y: -(videoSourceImageSize.height - cropY - cropSquareSize))
    }

    private func rotate(_ videoSourceImage: CIImage, _ settings: VideoSourceEffectSettings) -> CIImage {
        switch settings.rotation {
        case 90:
            return videoSourceImage.oriented(.right)
        case 180:
            return videoSourceImage.oriented(.down)
        case 270:
            return videoSourceImage.oriented(.left)
        default:
            return videoSourceImage
        }
    }

    override func execute(_ backgroundImage: CIImage, _ info: VideoEffectInfo) -> CIImage {
        guard let sceneWidget else {
            return backgroundImage
        }
        guard var widgetImage = info.getCiImage(videoSourceId) else {
            return backgroundImage
        }
        if settings.trackFaceEnabled {
            widgetImage = cropFace(
                widgetImage,
                info.faceDetections[videoSourceId],
                info.presentationTimeStamp.seconds,
                settings.trackFaceZoom
            )
        }
        return applyEffectsResizeMirrorMove(rotate(widgetImage, settings),
                                            sceneWidget,
                                            settings.mirror,
                                            backgroundImage.extent,
                                            info)
            .composited(over: backgroundImage)
    }
}
