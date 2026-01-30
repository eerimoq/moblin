import AVFoundation
import UIKit
import Vision

struct FaceEffectSettings {
    var blurFaces = true
    var blurText = true
    var blurBackground = true
    var showMouth = true
    var privacyMode: FaceEffectPrivacyMode = .blur(strength: 1.0)
}

enum FaceEffectPrivacyMode {
    case blur(strength: Float)
    case pixellate(strength: Float)
    case backgroundImage(CIImage)
    case faceImage(CIImage)
}

final class FaceEffect: VideoEffect {
    private var settings = FaceEffectSettings()
    let moblinImage: CIImage?

    override init() {
        if let image = UIImage(named: "AppIconNoBackground"), let image = image.cgImage {
            moblinImage = CIImage(cgImage: image)
        } else {
            moblinImage = nil
        }
    }

    func setSettings(settings: FaceEffectSettings) {
        processorPipelineQueue.async {
            self.settings = settings
        }
    }

    override func needsFaceDetections(_: Double) -> VideoEffectFaceDetectionsMode {
        return .now(nil)
    }

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        guard let detections = info.sceneDetections() else {
            return image
        }
        var outputImage: CIImage? = image
        if (settings.blurFaces && !detections.face.isEmpty)
            || (settings.blurText && !detections.text.isEmpty)
            || settings.blurBackground
        {
            outputImage = applyBlur(
                image: image,
                detections: detections,
                blurFaces: settings.blurFaces,
                blurText: settings.blurText,
                blurBackground: settings.blurBackground
            )
        }
        if settings.showMouth {
            outputImage = addMouth(image: outputImage, detections: detections.face)
        }
        return outputImage ?? image
    }

    private func makePrivacyImage(image: CIImage) -> CIImage? {
        switch settings.privacyMode {
        case let .blur(strength: strength):
            return image
                .applyingGaussianBlur(sigma: (image.extent.width / 50.0) * Double(strength))
                .cropped(to: image.extent)
        case let .pixellate(strength: strength):
            let filter = CIFilter.pixellate()
            filter.inputImage = image
            filter.center = .zero
            filter.scale = pixellateCalcScale(size: image.extent.size, strength: strength)
            return filter.outputImage?.cropped(to: image.extent) ?? image
        case let .backgroundImage(backgroundImage):
            return backgroundImage
                .scaledTo(size: image.extent.size)
        case .faceImage:
            return nil
        }
    }

    private func createFacesMaskImage(imageExtent: CGRect, detections: [VNFaceObservation]) -> CIImage? {
        var mask = CIImage.empty().cropped(to: imageExtent)
        for detection in detections {
            guard let boundingBox = detection.stableBoundingBox(imageSize: imageExtent.size) else {
                continue
            }
            let faceCenter = CGPoint(x: boundingBox.maxX - (boundingBox.width / 2),
                                     y: boundingBox.maxY - (boundingBox.height / 2))
            let faceMask = CIFilter.radialGradient()
            faceMask.center = faceCenter
            faceMask.radius0 = Float(boundingBox.height / 1.7)
            switch settings.privacyMode {
            case .blur:
                faceMask.radius1 = faceMask.radius0 * 1.5
            case .pixellate:
                faceMask.radius1 = faceMask.radius0 * 1.5
            case .backgroundImage:
                faceMask.radius1 = faceMask.radius0
            case .faceImage:
                faceMask.radius1 = faceMask.radius0
            }
            faceMask.color0 = CIColor.white
            faceMask.color1 = CIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0)
            guard let faceMask = faceMask.outputImage?.cropped(to: boundingBox.insetBy(
                dx: -boundingBox.width / 2,
                dy: -boundingBox.height / 2
            )) else {
                continue
            }
            mask = faceMask.composited(over: mask)
        }
        return mask
    }

    private func createTextsMaskImage(imageExtent: CGRect, detections: [TextDetection]) -> CIImage? {
        var mask = CIImage.empty().cropped(to: imageExtent)
        for detection in detections {
            let x = detection.boundingBox.origin.x * 1920
            let y = detection.boundingBox.origin.y * 1080
            let width = detection.boundingBox.width * 1920
            let height = detection.boundingBox.height * 1080
            let boundingBox = CGRect(x: x, y: y, width: width, height: height)
            mask = CIImage(color: .white)
                .cropped(to: boundingBox)
                .composited(over: mask)
        }
        return mask
    }

    private func applyBlur(image: CIImage,
                           detections: Detections,
                           blurFaces: Bool,
                           blurText: Bool,
                           blurBackground: Bool) -> CIImage?
    {
        let privacyImage = makePrivacyImage(image: image)
        var outputImage: CIImage? = image
        if (blurFaces && !detections.face.isEmpty) || blurBackground {
            let mask = createFacesMaskImage(imageExtent: image.extent, detections: detections.face)
            if blurFaces {
                let blender = CIFilter.blendWithMask()
                blender.inputImage = privacyImage
                blender.backgroundImage = image
                blender.maskImage = mask
                outputImage = blender.outputImage
            }
            if blurBackground {
                let blender = CIFilter.blendWithMask()
                blender.inputImage = outputImage
                blender.backgroundImage = privacyImage
                blender.maskImage = mask
                outputImage = blender.outputImage
            }
        }
        if blurText, !detections.text.isEmpty {
            let mask = createTextsMaskImage(imageExtent: image.extent, detections: detections.text)
            let blender = CIFilter.blendWithMask()
            blender.inputImage = privacyImage
            blender.backgroundImage = outputImage
            blender.maskImage = mask
            outputImage = blender.outputImage
        }
        return outputImage
    }

    private func addMouth(image: CIImage?, detections: [VNFaceObservation]?) -> CIImage? {
        guard let image, let detections, let moblinImage else {
            return image
        }
        var outputImage = image
        for detection in detections {
            guard let innerLips = detection.landmarks?.innerLips else {
                continue
            }
            let points = innerLips.pointsInImage(imageSize: image.extent.size)
            guard let firstPoint = points.first else {
                continue
            }
            var minX = firstPoint.x
            var maxX = firstPoint.x
            var minY = firstPoint.y
            var maxY = firstPoint.y
            for point in points {
                minX = min(point.x, minX)
                maxX = max(point.x, maxX)
                minY = min(point.y, minY)
                maxY = max(point.y, maxY)
            }
            let diffX = maxX - minX
            let diffY = maxY - minY
            if diffY <= diffX {
                continue
            }
            let moblinImage = moblinImage
                .scaled(x: diffX / moblinImage.extent.width, y: diffX / moblinImage.extent.width)
            let offsetY = minY + (diffY - moblinImage.extent.height) / 2
            outputImage = moblinImage
                .translated(x: minX, y: offsetY)
                .composited(over: outputImage)
        }
        return outputImage.cropped(to: image.extent)
    }
}
