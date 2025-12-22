import AVFoundation
import UIKit
import Vision

struct FaceEffectSettings {
    var showBlur = true
    var showBlurBackground = true
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

    override func getName() -> String {
        return "Face filter"
    }

    override func needsFaceDetections(_: Double) -> VideoEffectFaceDetectionsMode {
        return .now(nil)
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
            filter.scale = calcScale(size: image.extent.size, strength: strength)
            return filter.outputImage?.cropped(to: image.extent) ?? image
        case let .backgroundImage(backgroundImage):
            return backgroundImage
                .scaledTo(size: image.extent.size)
        case .faceImage:
            return nil
        }
    }

    private func createFacesMaskImage(imageExtent: CGRect, faceDetections: [VNFaceObservation]) -> CIImage? {
        var facesMask = CIImage.empty().cropped(to: imageExtent)
        for faceDetection in faceDetections {
            guard let faceBoundingBox = faceDetection.stableBoundingBox(imageSize: imageExtent.size) else {
                continue
            }
            let faceCenter = CGPoint(x: faceBoundingBox.maxX - (faceBoundingBox.width / 2),
                                     y: faceBoundingBox.maxY - (faceBoundingBox.height / 2))
            let faceMask = CIFilter.radialGradient()
            faceMask.center = faceCenter
            faceMask.radius0 = Float(faceBoundingBox.height / 1.7)
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
            guard let faceMask = faceMask.outputImage?.cropped(to: faceBoundingBox.insetBy(
                dx: -faceBoundingBox.width / 2,
                dy: -faceBoundingBox.height / 2
            )) else {
                continue
            }
            facesMask = faceMask.composited(over: facesMask)
        }
        return facesMask
    }

    private func applyFacesMask(image: CIImage,
                                faceDetections: [VNFaceObservation],
                                blurFaces: Bool,
                                blurBackground: Bool) -> CIImage?
    {
        let privacyImage = makePrivacyImage(image: image)
        let mask = createFacesMaskImage(imageExtent: image.extent, faceDetections: faceDetections)
        var outputImage = privacyImage
        if blurFaces {
            let faceBlender = CIFilter.blendWithMask()
            faceBlender.inputImage = privacyImage
            faceBlender.backgroundImage = image
            faceBlender.maskImage = mask
            outputImage = faceBlender.outputImage
        } else {
            outputImage = image
        }
        if blurBackground {
            let faceBlender = CIFilter.blendWithMask()
            faceBlender.inputImage = outputImage
            faceBlender.backgroundImage = privacyImage
            faceBlender.maskImage = mask
            outputImage = faceBlender.outputImage
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

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        let faceDetections = info.sceneFaceDetections()
        guard let faceDetections else {
            return image
        }
        var outputImage: CIImage? = image
        if (settings.showBlur && !faceDetections.isEmpty) || settings.showBlurBackground {
            outputImage = applyFacesMask(
                image: image,
                faceDetections: faceDetections,
                blurFaces: settings.showBlur,
                blurBackground: settings.showBlurBackground
            )
        }
        if settings.showMouth {
            outputImage = addMouth(image: outputImage, detections: faceDetections)
        }
        return outputImage ?? image
    }

    private func calcScale(size: CGSize, strength: Float) -> Float {
        let maximum = Float(size.maximum())
        let sizeInPixels = 20 * (maximum / 1920) * (1 + 5 * strength)
        return maximum / Float(Int(maximum / sizeInPixels))
    }
}
