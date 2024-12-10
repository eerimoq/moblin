import CoreVideo
import Foundation

extension CVPixelBuffer {
    var width: Int {
        CVPixelBufferGetWidth(self)
    }

    var height: Int {
        CVPixelBufferGetHeight(self)
    }

    var size: CGSize {
        .init(width: width, height: height)
    }

    func isPortrait() -> Bool {
        return height > width
    }
}
