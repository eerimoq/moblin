import AVFoundation
import UIKit
import Vision

struct FaceEffectSettings {
    var showBlur = true
    var showBlurBackground = true
    var showMouth = true
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

    override func getName() -> String {
        return "Face filter"
    }

    override func needsFaceDetections(_: Double) -> (Bool, UUID?, Double?) {
        return (true, nil, nil)
    }

    func setSettings(settings: FaceEffectSettings) {
        processorPipelineQueue.async {
            self.settings = settings
        }
    }

    private func addBlur(image: CIImage?) -> CIImage? {
        guard let image else {
            return image
        }
        return image
            .clampedToExtent()
            .applyingGaussianBlur(sigma: image.extent.width / 50.0)
            .cropped(to: image.extent)
    }

    private func createFacesMaskImage(imageExtent: CGRect, detections: [VNFaceObservation]) -> CIImage? {
        var facesMask = CIImage.empty().cropped(to: imageExtent)
        for detection in detections {
            let faceBoundingBox = CGRect(x: detection.boundingBox.minX * imageExtent.width,
                                         y: detection.boundingBox.minY * imageExtent.height,
                                         width: detection.boundingBox.width * imageExtent.width,
                                         height: detection.boundingBox.height * imageExtent.height)
            let faceCenter = CGPoint(x: faceBoundingBox.maxX - (faceBoundingBox.width / 2),
                                     y: faceBoundingBox.maxY - (faceBoundingBox.height / 2))
            let faceMask = CIFilter.radialGradient()
            faceMask.center = faceCenter
            faceMask.radius0 = Float(faceBoundingBox.height / 2)
            faceMask.radius1 = Float(faceBoundingBox.height)
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

    private func applyFacesMask(image: CIImage?,
                                detections: [VNFaceObservation]?,
                                blurFaces: Bool,
                                blurBackground: Bool) -> CIImage?
    {
        guard let image, let detections else {
            return image
        }
        let blurredImage = addBlur(image: image)
        let mask = createFacesMaskImage(imageExtent: image.extent, detections: detections)
        var outputImage: CIImage? = blurredImage
        if blurFaces {
            let faceBlender = CIFilter.blendWithMask()
            faceBlender.inputImage = blurredImage
            faceBlender.backgroundImage = image
            faceBlender.maskImage = mask
            outputImage = faceBlender.outputImage
        } else {
            outputImage = image
        }
        if blurBackground {
            let faceBlender = CIFilter.blendWithMask()
            faceBlender.inputImage = outputImage
            faceBlender.backgroundImage = blurredImage
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
        if settings.showBlur || settings.showBlurBackground {
            outputImage = applyFacesMask(
                image: image,
                detections: faceDetections,
                blurFaces: settings.showBlur,
                blurBackground: settings.showBlurBackground
            )
        }
        if settings.showMouth {
            outputImage = addMouth(image: outputImage, detections: faceDetections)
        }
        return outputImage ?? image
    }
}
