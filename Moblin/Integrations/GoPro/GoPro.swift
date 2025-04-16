import SwiftUI

class GoPro {
    static func generateWifiCredentialsQrCode(ssid: String, password: String) -> UIImage? {
        return generateQrCode(from: "!MJOIN=\"\(ssid):\(password)\"")
    }

    static func generateRtmpUrlQrCode(url: String) -> UIImage? {
        return generateQrCode(from: "!MRTMP=\"\(url)\"")
    }
}
