import AVFoundation
import MetalPetal
import Vision

struct VideoSourceEffectSettings {
    var cornerRadius: Float = 0
    var cropEnabled: Bool = false
    var cropX: Double = 0
    var cropY: Double = 0
    var cropWidth: Double = 1
    var cropHeight: Double = 1
    var rotation: Double = 0
    var trackFaceEnabled: Bool = false
    var trackFaceZoom: Double = 2.2
    var mirror: Bool = false
}

class PositionInterpolator {
    private(set) var current: Double?
    var target: Double?

    init() {}

    func update(timeElapsed: Double) -> Double {
        if let current, let target {
            let delta = target - current
            if abs(delta) < 5 {
                self.current = current
            } else {
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
    private var videoSourceId: Atomic<UUID> = .init(.init())
    private var sceneWidget: Atomic<SettingsSceneWidget?> = .init(nil)
    private var settings: Atomic<VideoSourceEffectSettings> = .init(.init())
    private let trackFaceLeft = PositionInterpolator()
    private let trackFaceRight = PositionInterpolator()
    private let trackFaceTop = PositionInterpolator()
    private let trackFaceBottom = PositionInterpolator()
    private var trackFacePresentationTimeStamp = 0.0
    private var trackFaceNeedsDetectionsPresentationTimeStamp = 0.0

    override func getName() -> String {
        return "video source"
    }

    override func needsFaceDetections(_ presentationTimeStamp: Double) -> (Bool, UUID?) {
        if presentationTimeStamp - trackFaceNeedsDetectionsPresentationTimeStamp > 0.2 {
            trackFaceNeedsDetectionsPresentationTimeStamp = presentationTimeStamp
            return (settings.value.trackFaceEnabled, videoSourceId.value)
        } else {
            return (false, nil)
        }
    }

    func setVideoSourceId(videoSourceId: UUID) {
        self.videoSourceId.mutate { $0 = videoSourceId }
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget?) {
        self.sceneWidget.mutate { $0 = sceneWidget }
    }

    func setSettings(settings: VideoSourceEffectSettings) {
        self.settings.mutate { $0 = settings }
    }

    private func interpolatePosition(_ current: Double?, _ target: Double?, _ timeElapsed: Double) -> Double {
        if let current, let target {
            let delta = target - current
            if abs(delta) < 5 {
                return current
            } else {
                return current + delta * 2 * timeElapsed
            }
        } else if let target {
            return target
        } else {
            return 0
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
        if let faceDetections, !faceDetections.isEmpty {
            for faceDetection in faceDetections {
                guard let boundingBox = faceDetection.stableBoundingBox(imageSize: videoSourceImageSize) else {
                    continue
                }
                left = min(left, boundingBox.minX)
                right = max(right, boundingBox.maxX)
                top = max(top, boundingBox.maxY)
                bottom = min(bottom, boundingBox.minY)
            }
            trackFaceLeft.target = left
            trackFaceRight.target = right
            trackFaceTop.target = top
            trackFaceBottom.target = bottom
        } else if trackFaceLeft.target == nil {
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
        let centerY = (top + bottom) / 2 * 1.05 // - extraHeight
        let side = max(width, height)
        let cropWidth = min(side, videoSourceImageSize.width)
        let cropHeight = min(side, videoSourceImageSize.height)
        let cropSquareSize = min(cropWidth, cropHeight).rounded(.down)
        var cropX = max(centerX - cropSquareSize / 2, 0)
        var cropY = max(videoSourceImageSize.height - centerY - cropSquareSize / 2, 0)
        cropX = min(cropX, videoSourceImage.extent.width - cropSquareSize)
        cropY = min(cropY, videoSourceImage.extent.height - cropSquareSize)
        return videoSourceImage
            .cropped(to: .init(
                x: cropX,
                y: videoSourceImage.extent.height - cropY - cropSquareSize,
                width: cropSquareSize,
                height: cropSquareSize
            ))
            .transformed(by: CGAffineTransform(
                translationX: -cropX,
                y: -(videoSourceImage.extent.height - cropY - cropSquareSize)
            ))
    }

    private func crop(_ videoSourceImage: CIImage, _ settings: VideoSourceEffectSettings) -> CIImage {
        let cropX = toPixels(100 * settings.cropX, videoSourceImage.extent.width)
        let cropY = toPixels(100 * settings.cropY, videoSourceImage.extent.height)
        let cropWidth = toPixels(100 * settings.cropWidth, videoSourceImage.extent.width)
        let cropHeight = toPixels(100 * settings.cropHeight, videoSourceImage.extent.height)
        return videoSourceImage
            .cropped(to: .init(
                x: cropX,
                y: videoSourceImage.extent.height - cropY - cropHeight,
                width: cropWidth,
                height: cropHeight
            ))
            .transformed(by: CGAffineTransform(
                translationX: -cropX,
                y: -(videoSourceImage.extent.height - cropY - cropHeight)
            ))
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

    private func makeRoundedRectangleMask(
        _ videoSourceImage: CIImage,
        _ cornerRadius: Float,
        _ translation: CGAffineTransform,
        _ crop: CGRect,
        _ clearBackgroundImage: CIImage
    ) -> CIImage? {
        let roundedRectangleGenerator = CIFilter.roundedRectangleGenerator()
        roundedRectangleGenerator.color = .green
        // Slightly smaller to remove ~1px black line around image.
        var extent = videoSourceImage.extent
        extent.origin.x += 1
        extent.origin.y += 1
        extent.size.width -= 2
        extent.size.height -= 2
        roundedRectangleGenerator.extent = extent
        var radiusPixels = Float(min(videoSourceImage.extent.height, videoSourceImage.extent.width))
        radiusPixels /= 2
        radiusPixels *= cornerRadius
        roundedRectangleGenerator.radius = radiusPixels
        return roundedRectangleGenerator.outputImage?
            .transformed(by: translation)
            .cropped(to: crop)
            .composited(over: clearBackgroundImage)
    }

    private func makeScale(
        _ videoSourceImage: CIImage,
        _ sceneWidget: SettingsSceneWidget,
        _ size: CGSize,
        _ mirror: Bool
    ) -> (Double, Double) {
        var scaleX = toPixels(sceneWidget.width, size.width) / videoSourceImage.extent.size.width
        let scaleY = toPixels(sceneWidget.height, size.height) / videoSourceImage.extent.size.height
        let scale = min(scaleX, scaleY)
        if mirror {
            scaleX = -1 * scale
        } else {
            scaleX = scale
        }
        return (scaleX, scale)
    }

    private func makeTranslation(
        _ videoSourceImage: CIImage,
        _ sceneWidget: SettingsSceneWidget,
        _ size: CGSize,
        _ scaleX: Double,
        _ scaleY: Double,
        _ mirror: Bool
    ) -> CGAffineTransform {
        var x = toPixels(sceneWidget.x, size.width)
        if mirror {
            x -= videoSourceImage.extent.width * scaleX
        }
        let y = size.height - toPixels(sceneWidget.y, size.height) - videoSourceImage.extent.height * scaleY
        return CGAffineTransform(translationX: x, y: y)
    }

    private func makeSharpCornersImage(
        _ videoSourceImage: CIImage,
        _ backgroundImage: CIImage,
        _ translation: CGAffineTransform,
        _ crop: CGRect
    ) -> CIImage {
        return videoSourceImage
            .transformed(by: translation)
            .cropped(to: crop)
            .composited(over: backgroundImage)
    }

    private func makeRoundedCornersImage(
        _ videoSourceImage: CIImage,
        _ backgroundImage: CIImage,
        _ translation: CGAffineTransform,
        _ crop: CGRect,
        _ settings: VideoSourceEffectSettings
    ) -> CIImage {
        let clearBackgroundImage = CIImage.clear.cropped(to: backgroundImage.extent)
        let roundedRectangleMask = makeRoundedRectangleMask(
            videoSourceImage,
            settings.cornerRadius,
            translation,
            crop,
            clearBackgroundImage
        )
        let videoSourceImage = videoSourceImage
            .transformed(by: translation)
            .cropped(to: crop)
            .composited(over: clearBackgroundImage)
        let roundedCornersBlender = CIFilter.blendWithMask()
        roundedCornersBlender.inputImage = videoSourceImage
        roundedCornersBlender.backgroundImage = backgroundImage
        roundedCornersBlender.maskImage = roundedRectangleMask
        return roundedCornersBlender.outputImage ?? backgroundImage
    }

    override func execute(_ backgroundImage: CIImage, _ info: VideoEffectInfo) -> CIImage {
        guard let sceneWidget = sceneWidget.value else {
            return backgroundImage
        }
        let settings = self.settings.value
        let videoSourceId = videoSourceId.value
        guard var videoSourceImage = info.videoUnit.getCIImage(
            videoSourceId,
            info.presentationTimeStamp
        )
        else {
            return backgroundImage
        }
        if videoSourceImage.extent.height > videoSourceImage.extent.width {
            videoSourceImage = videoSourceImage.oriented(.left)
        }
        if settings.trackFaceEnabled {
            videoSourceImage = cropFace(
                videoSourceImage,
                info.faceDetections[videoSourceId],
                info.presentationTimeStamp.seconds,
                settings.trackFaceZoom
            )
        } else if settings.cropEnabled {
            videoSourceImage = crop(videoSourceImage, settings)
        }
        videoSourceImage = rotate(videoSourceImage, settings)
        let size = backgroundImage.extent.size
        let (scaleX, scaleY) = makeScale(videoSourceImage, sceneWidget, size, settings.mirror)
        let translation = makeTranslation(videoSourceImage, sceneWidget, size, scaleX, scaleY, settings.mirror)
        let crop = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        videoSourceImage = videoSourceImage
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        if settings.cornerRadius == 0 {
            return makeSharpCornersImage(videoSourceImage, backgroundImage, translation, crop)
        } else {
            return makeRoundedCornersImage(videoSourceImage, backgroundImage, translation, crop, settings)
        }
    }

    override func executeMetalPetal(_ image: MTIImage?, _: VideoEffectInfo) -> MTIImage? {
        return image
    }
}
