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

    override func execute(_ image: CIImage, _ faceDetections: [VNFaceObservation]?) -> CIImage {
        guard let faceDetections else {
            return image
        }
        var faceMaskImage = CIImage.empty().cropped(to: image.extent)
        for faceDetection in faceDetections {
            let faceRect = CGRect(x: faceDetection.boundingBox.minX * image.extent.width,
                                  y: faceDetection.boundingBox.minY * image.extent.height,
                                  width: faceDetection.boundingBox.width * image.extent.width,
                                  height: faceDetection.boundingBox.height * image.extent.height)
            let maskCenter = CGPoint(x: faceRect.maxX - (faceRect.width / 2),
                                     y: faceRect.maxY - (faceRect.height / 2))
            let faceMaskFilter = CIFilter.radialGradient()
            faceMaskFilter.center = maskCenter
            faceMaskFilter.radius0 = Float(faceRect.height / 2)
            faceMaskFilter.radius1 = Float(faceRect.height)
            faceMaskFilter.color0 = CIColor.white
            faceMaskFilter.color1 = CIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.0)
            guard let gradientOutput = faceMaskFilter.outputImage?.cropped(to: faceRect.insetBy(
                dx: -faceRect.width / 2,
                dy: -faceRect.height / 2
            )) else {
                continue
            }
            faceMaskImage = gradientOutput.composited(over: faceMaskImage)
        }
        let blurRadius = 30.0
        let blurredImage = image
            .clampedToExtent()
            .applyingGaussianBlur(sigma: blurRadius)
            .cropped(to: image.extent)
        faceBlender.inputImage = blurredImage
        faceBlender.backgroundImage = image
        faceBlender.maskImage = faceMaskImage
        return faceBlender.outputImage ?? image
    }
}
