import CoreImage
import MetalPetal
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

final class VideoSourceEffect: VideoEffect, @unchecked Sendable {
    private var videoSourceId: UUID = .init()
    private var sceneWidget: SettingsSceneWidget?
    private var settings: VideoSourceEffectSettings = .init()
    private let trackFaceLeft = PositionInterpolator()
    private let trackFaceRight = PositionInterpolator()
    private let trackFaceTop = PositionInterpolator()
    private let trackFaceBottom = PositionInterpolator()
    private var trackFacePresentationTimeStamp = 0.0

    override func needsFaceDetections(_: Double) -> VideoEffectDetectionsMode {
        if settings.trackFaceEnabled {
            .interval(videoSourceId, 0.5)
        } else {
            .off
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
            false
        } else if boundingBox.height < biggestBoundingBox.height / 2 {
            false
        } else {
            true
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
                guard let boundingBox = faceDetection.stableBoundingBox(imageSize: videoSourceImageSize)
                else {
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
            videoSourceImage.oriented(.right)
        case 180:
            videoSourceImage.oriented(.down)
        case 270:
            videoSourceImage.oriented(.left)
        default:
            videoSourceImage
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
                info.faceDetections(videoSourceId),
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

    // Only the simple, common case is natively implemented here: no rotation, no
    // face-tracking crop, no attached sub-effects. Rotation and face-tracking both involve
    // coordinate-system conventions (content-region cropping, discrete rotation direction)
    // that can't be visually verified from here, and sub-effects are arbitrary CIFilter
    // chains that aren't natively portable without a lot more work. All of those fall back
    // to the exact existing, unchanged CoreImage execute(_:_:) via the base class bridge.
    override func executeMetalPetal(_ backgroundImage: MTIImage, _ info: VideoEffectInfo) -> MTIImage {
        guard metalPetalFastPaths,
              let sceneWidget,
              settings.rotation == 0,
              !settings.trackFaceEnabled,
              effects.isEmpty
        else {
            return super.executeMetalPetal(backgroundImage, info)
        }
        guard let widgetImage = info.getMetalPetalImage(videoSourceId) else {
            return backgroundImage
        }
        let canvasSize = backgroundImage.extent.size
        let scaleX = toPixels(sceneWidget.layout.size, canvasSize.width) / widgetImage.extent.width
        let scaleY = toPixels(sceneWidget.layout.size, canvasSize.height) / widgetImage.extent.height
        let scale = min(scaleX, scaleY)
        let scaledSize = CGSize(
            width: widgetImage.extent.width * scale,
            height: widgetImage.extent.height * scale
        )
        // move(_:_:) is CIImage's existing, proven alignment math (bottom-left origin, Y
        // up); applied to a zero-cost placeholder (never rendered) purely to reuse it, then
        // converted into MetalPetal's Layer.position convention (top-left origin, Y down,
        // position is the center) -- same conversion validated for TextEffect.
        let movedExtent = CIImage.black
            .cropped(to: CGRect(origin: .zero, size: scaledSize))
            .move(sceneWidget.layout, canvasSize)
            .extent
        let position = CGPoint(
            x: movedExtent.minX + movedExtent.width / 2,
            y: canvasSize.height - movedExtent.minY - movedExtent.height / 2
        )
        let filter = MultilayerCompositingFilter()
        filter.inputBackgroundImage = backgroundImage
        filter.layers = [
            .content(widgetImage, modifier: { layer in
                layer.layoutUnit = .pixel
                layer.size = scaledSize
                layer.position = position
                if self.settings.mirror {
                    layer.contentFlipOptions = .flipHorizontally
                }
            }),
        ]
        return filter.outputImage ?? backgroundImage
    }
}
