import AVFoundation
import Foundation

var allowVideoRangePixelFormat = false

extension AVCaptureDevice {
    func findVideoFormat(
        width: Int32,
        height: Int32,
        frameRate: Float64,
        colorSpace: AVCaptureColorSpace
    ) -> AVCaptureDevice.Format? {
        let formats = formats
            .filter { $0.isFrameRateSupported(frameRate) }
            .filter { $0.formatDescription.dimensions.width == width }
            .filter { $0.formatDescription.dimensions.height == height }
            .filter { $0.supportedColorSpaces.contains(colorSpace) }
            .filter { !$0.isVideoBinned }
            // 420v does not work with OA4.
            .filter {
                $0.formatDescription.mediaSubType
                    .rawValue != kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange || allowVideoRangePixelFormat
            }
        // for format in formats {
        //    print("xxx", format)
        // }
        return formats.first
    }
}
