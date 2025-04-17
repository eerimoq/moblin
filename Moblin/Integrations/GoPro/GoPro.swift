import SwiftUI

class GoPro {
    static func generateLaunchLiveStream(isHero12Or13: Bool) -> UIImage? {
        if isHero12Or13 {
            return generateQrCode(from: "!GL")
        } else {
            return generateQrCode(from: "oW1mVr1080!W!GL")
        }
    }

    static func generateWifiCredentialsQrCode(ssid: String, password: String) -> UIImage? {
        return generateQrCode(from: "!MJOIN=\"\(ssid):\(password)\"")
    }

    static func generateRtmpUrlQrCode(url: String) -> UIImage? {
        return generateQrCode(from: "!MRTMP=\"\(url)\"")
    }
}
