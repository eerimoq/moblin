import AVFoundation
import Foundation

extension AVCaptureSession.Preset {
    var width: Int32? {
        switch self {
        case .hd4K3840x2160:
            return 3840
        case .hd1920x1080:
            return 1920
        case .hd1280x720:
            return 1280
        case .vga640x480:
            return 640
        case .cif352x288:
            return 352
        default:
            return nil
        }
    }

    var height: Int32? {
        switch self {
        case .hd4K3840x2160:
            return 2160
        case .hd1920x1080:
            return 1080
        case .hd1280x720:
            return 720
        case .vga640x480:
            return 480
        case .cif352x288:
            return 288
        default:
            return nil
        }
    }
}
