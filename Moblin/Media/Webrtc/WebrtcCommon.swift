import libdatachannel

let defaultStunServer = "stun:stun.l.google.com:19302"

func setupWebrtcDebugLogging() {
    rtcInitLogger(RTC_LOG_DEBUG) { _, message in
        guard let message else {
            return
        }
        logger.info("webrtc: \(String(cString: message))")
    }
}
