import SwiftUI

class GoPro {
    static func generateLaunchLiveStream(isHero12Or13: Bool,
                                         resolution: SettingsGoProLaunchLiveStreamResolution) -> UIImage?
    {
        let suffix = switch resolution {
        case .r1080p:
            "!GL"
        case .r720p:
            "!GM"
        case .r480p:
            "!GS"
        }
        if isHero12Or13 {
            return generateQrCode(from: suffix)
        } else {
            return generateQrCode(from: "oW1mVr1080!W\(suffix)")
        }
    }

    static func generateWifiCredentialsQrCode(ssid: String, password: String) -> UIImage? {
        generateQrCode(from: "!MJOIN=\"\(ssid):\(password)\"")
    }

    static func generateRtmpUrlQrCode(url: String) -> UIImage? {
        generateQrCode(from: "!MRTMP=\"\(url)\"")
    }
}
