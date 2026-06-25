import AVFoundation
import CoreMedia
import Foundation

enum RtmpVideoFourCC: UInt32 {
    case avc1 = 0x6176_6331 // H.264
    case hvc1 = 0x6876_6331 // HEVC
    case av01 = 0x6176_3031 // AV1

    var flvCodecId: UInt8 {
        switch self {
        case .avc1: 7
        case .hvc1, .av01: 12 // Extended codec for Enhanced RTMP
        }
    }

    var isEnhanced: Bool {
        self != .avc1
    }
}

struct RtmpEnhancedCapabilities {
    let supportedFourCCs: [RtmpVideoFourCC]

    static func fromConnectResponse(_ response: AsObject) -> RtmpEnhancedCapabilities {
        var supported: [RtmpVideoFourCC] = [.avc1]

        if let videoFourCcInfoMap = response["videoFourCcInfoMap"] as? AsObject {
            if videoFourCcInfoMap["hvc1"] != nil { supported.append(.hvc1) }
            if videoFourCcInfoMap["av01"] != nil { supported.append(.av01) }
        } else if let videoFourCcInfoMap = response["videoFourCcInfoMap"] as? [String: Any] {
            if videoFourCcInfoMap["hvc1"] != nil { supported.append(.hvc1) }
            if videoFourCcInfoMap["av01"] != nil { supported.append(.av01) }
        }

        return RtmpEnhancedCapabilities(supportedFourCCs: supported)
    }
}
