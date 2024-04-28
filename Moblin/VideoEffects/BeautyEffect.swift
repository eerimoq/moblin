import AVFoundation
import UIKit
import Vision

final class BeautyEffect: VideoEffect {
    private let faceBlender = CIFilter.blendWithMask()

    override func getName() -> String {
        return "beauty filter"
    }

    override func needsFaceDetections() -> Bool {
        return true
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

    override func execute(_ image: CIImage, _ faceDetections: [VNFaceObservation]?) -> CIImage {
        guard let faceDetections else {
            return image
        }
        let facesMaskImage = createFacesMaskImage(imageExtent: image.extent, detections: faceDetections)
        let blurredImage = image
            .clampedToExtent()
            .applyingGaussianBlur(sigma: image.extent.width / 50.0)
            .cropped(to: image.extent)
        faceBlender.inputImage = blurredImage
        faceBlender.backgroundImage = image
        faceBlender.maskImage = facesMaskImage
        let scaleDownFactor = 0.8
        let width = image.extent.width
        let height = image.extent.height
        let scaleUpFactor = 1 / scaleDownFactor
        let smallWidth = width * scaleDownFactor
        let smallHeight = height * scaleDownFactor
        let smallOffsetX = (width - smallWidth) / 2
        let smallOffsetY = (height - smallHeight) / 2
        let croppedImage = faceBlender
            .outputImage?
            .cropped(to: CGRect(x: smallOffsetX, y: smallOffsetY, width: smallWidth, height: smallHeight))
            .transformed(by: CGAffineTransform(translationX: -smallOffsetX, y: -smallOffsetY))
            .transformed(by: CGAffineTransform(scaleX: scaleUpFactor, y: scaleUpFactor))
            .cropped(to: image.extent)
        return croppedImage ?? image
    }
}
