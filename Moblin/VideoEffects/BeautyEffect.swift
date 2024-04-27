import AVFoundation
import UIKit
import Vision

final class BeautyEffect: VideoEffect {
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
        for faceDetection in faceDetections {
            if let landmarks = faceDetection.landmarks {
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
            }
        }
        return image
    }
}
