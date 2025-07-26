import SwiftUI

class GoPro {
    static func generateLaunchLiveStream(isHero12Or13: Bool,
                                         resolution: SettingsGoProLaunchLiveStreamResolution) -> UIImage?
    {
        let suffix: String
        switch resolution {
        case .r1080p:
            suffix = "!GL"
        case .r720p:
            suffix = "!GM"
        case .r480p:
            suffix = "!GS"
        }
        if isHero12Or13 {
            return generateQrCode(from: suffix)
        } else {
            return generateQrCode(from: "oW1mVr1080!W\(suffix)")
        }
    }

    static func generateWifiCredentialsQrCode(ssid: String, password: String) -> UIImage? {
        return generateQrCode(from: "!MJOIN=\"\(ssid):\(password)\"")
    }

    static func generateRtmpUrlQrCode(url: String) -> UIImage? {
        return generateQrCode(from: "!MRTMP=\"\(url)\"")
    }
}
