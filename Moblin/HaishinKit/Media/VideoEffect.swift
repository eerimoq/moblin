import AVFoundation
import CoreImage
import Vision

open class VideoEffect: NSObject {
    open func getName() -> String {
        return ""
    }

    open func needsFaceDetections() -> Bool {
        return false
    }

    open func execute(_ image: CIImage, _: [VNFaceObservation]?) -> CIImage {
        image
    }
}
