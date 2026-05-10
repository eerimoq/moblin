@preconcurrency public import AVFoundation
import Foundation

extension AVCaptureColorSpace: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .sRGB:
            "SRGB"
        case .P3_D65:
            "P3_D65"
        case .HLG_BT2020:
            "HLG_BT2020"
        case .appleLog:
            "Apple Log"
        default:
            "Unknown"
        }
    }
}
