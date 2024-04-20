import Foundation

enum FLVVideoFourCC: UInt32 {
    case av1 = 0x6176_3031 // { 'a', 'v', '0', '1' }
    case vp9 = 0x7670_3039 // { 'v', 'p', '0', '9' }
    case hevc = 0x6876_6331 // { 'h', 'v', 'c', '1' }

    var isSupported: Bool {
        switch self {
        case .av1:
            return false
        case .vp9:
            return false
        case .hevc:
            return true
        }
    }
}
