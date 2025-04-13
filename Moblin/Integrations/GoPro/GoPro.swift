class GoPro {
    private var wifiSsid = ""
    private var wifiPassword = ""
    private var rtmpUrl = ""

    func generateWiFiQrCode() {
        let message = "!MJOIN=\"\(wifiSsid):\(wifiPassword)\""
        logger.info("xxx wifi \(message)")
    }

    func generateRtmpQrCode() {
        let message = "!MRTMP=\"\(rtmpUrl)\""
        logger.info("xxx RTMP \(message)")
    }
}
