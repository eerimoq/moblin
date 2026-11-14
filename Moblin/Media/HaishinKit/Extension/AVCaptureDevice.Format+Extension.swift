import AVFoundation
import Foundation

extension AVCaptureDevice.Format {
    func isFrameRateSupported(_ fps: Float64) -> Bool {
        for fpsRange in videoSupportedFrameRateRanges where fpsRange.contains(frameRate: fps) {
            return true
        }
        return false
    }
}
