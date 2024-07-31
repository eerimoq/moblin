import AVFoundation
import CoreImage.CIFilterBuiltins
import MetalPetal
import Vision

open class VideoEffect: NSObject {
    open func getName() -> String {
        return ""
    }

    open func needsFaceDetections() -> Bool {
        return false
    }

    open func execute(_ image: CIImage, _: [VNFaceObservation]?, _: Bool) -> CIImage {
        return image
    }

    open func executeMetalPetal(_ image: MTIImage?, _: [VNFaceObservation]?, _: Bool) -> MTIImage? {
        return image
    }

    open func removed() {}

    open func shouldRemove() -> Bool {
        return false
    }
}
