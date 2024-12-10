import AVFoundation
import Foundation

extension AVCaptureColorSpace: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case .sRGB:
            return "SRGB"
        case .P3_D65:
            return "P3_D65"
        case .HLG_BT2020:
            return "HLG_BT2020"
        case .appleLog:
            return "Apple Log"
        default:
            return "Unknown"
        }
    }
}
