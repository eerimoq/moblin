import AVFoundation
import Foundation

extension AVFrameRateRange {
    func contains(frameRate: Float64) -> Bool {
        (minFrameRate ... maxFrameRate) ~= frameRate
    }
}
