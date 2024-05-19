import AVFoundation
import CoreImage
import MetalPetal
import Vision

open class VideoEffect: NSObject {
    open func getName() -> String {
        return ""
    }

    open func needsFaceDetections() -> Bool {
        return false
    }

    open func execute(_ image: CIImage, _: [VNFaceObservation]?) -> CIImage {
        return image
    }

    open func executeMetalPetal(_ image: MTIImage?, _: [VNFaceObservation]?) -> MTIImage? {
        return image
    }

    open func removed() {}
}
