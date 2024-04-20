import AVFoundation
import Foundation

extension AVCaptureDevice {
    func findVideoFormat(
        width: Int32,
        height: Int32,
        frameRate: Float64,
        colorSpace: AVCaptureColorSpace
    ) -> AVCaptureDevice.Format? {
        return formats
            .filter { $0.isFrameRateSupported(frameRate) }
            .filter { $0.formatDescription.dimensions.width == width }
            .filter { $0.formatDescription.dimensions.height == height }
            .filter { $0.supportedColorSpaces.contains(colorSpace) }
            .filter { !$0.isVideoBinned }
            .last
    }
}
