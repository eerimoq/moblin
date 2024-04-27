import AVFoundation
import UIKit
import Vision

final class BeautyEffect: VideoEffect {
    private let faceBlender = CIFilter.blendWithMask()
    private let lipsBlender = CIFilter.blendWithMask()

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
        let faceMaskImage = CIImage.empty().cropped(to: image.extent)
        let lipsMaskImage = CIImage.empty().cropped(to: image.extent)
        for faceDetection in faceDetections {
            print("Face bounding box:", faceDetection.boundingBox)
            /* if let landmarks = faceDetection.landmarks {
                 if let faceContour = landmarks.faceContour {
                     print("faceContour", faceContour.normalizedPoints)
                 }
                 if let innerLips = landmarks.innerLips {
                     print("innerLips", innerLips.normalizedPoints)
                 }
                 if let outerLips = landmarks.outerLips {
                     print("outerLips", outerLips.normalizedPoints)
                 }
                 if let medianLine = landmarks.medianLine {
                     print("medianLine", medianLine.normalizedPoints)
                 }
             } */
        }
        faceBlender.inputImage = image
        faceBlender.backgroundImage = image
        faceBlender.maskImage = faceMaskImage
        lipsBlender.inputImage = image
        lipsBlender.backgroundImage = faceBlender.outputImage
        lipsBlender.maskImage = lipsMaskImage
        return lipsBlender.outputImage ?? image
    }
}
