import AVFoundation
import HaishinKit
import SRTHaishinKit

let mediaDispatchQueue = DispatchQueue(label: "com.eerimoq.stream")

private func isMuted(level: Float) -> Bool {
    return level.isNaN
}

private func becameMuted(old: Float, new: Float) -> Bool {
    return !isMuted(level: old) && isMuted(level: new)
}

private func becameUnmuted(old: Float, new: Float) -> Bool {
    return isMuted(level: old) && !isMuted(level: new)
}

final class Media: NSObject {
    private var rtmpConnection = RTMPConnection()
    private var srtConnection = SRTConnection()
    private var rtmpStream: RTMPStream?
    private var srtStream: SRTStream?
    private var srtla: Srtla?
    private var netStream: NetStream!
    private var srtTotalByteCount: Int64 = 0
    private var srtPreviousTotalByteCount: Int64 = 0
    private var srtSpeed: Int64 = 0
    private var srtConnectedObservation: NSKeyValueObservation?
    private var rtmpStreamName = ""
    private var currentAudioLevel: Float = 100.0
    private var numberOfAudioChannels = 0
    private var numberOfAudioSamples = 0
    private var srtUrl: String = ""
    private var latency: Int32 = 2000
    private var overheadBandwidth: Int32 = 25
    var onSrtConnected: (() -> Void)!
    var onSrtDisconnected: ((_ reason: String) -> Void)!
    var onRtmpConnected: (() -> Void)!
    var onRtmpDisconnected: ((_ message: String) -> Void)!
    var onAudioMuteChange: (() -> Void)!
    var onVideoDeviceInUseByAnotherClient: (() -> Void)!
    private var adaptiveBitrate: AdaptiveBitrate?

    func logStatistics() {
        srtla?.logStatistics()
    }

    func logAudioStatistics() {
        logger
            .debug(
                """
                Audio: channels: \(numberOfAudioChannels), \
                samples: \(numberOfAudioSamples)
                """
            )
    }

    func srtlaConnectionStatistics() -> String? {
        return srtla?.connectionStatistics() ?? nil
    }

    func setNetStream(proto: SettingsStreamProtocol) {
        srtStopStream()
        rtmpStopStream()
        rtmpConnection = RTMPConnection()
        switch proto {
        case .rtmp:
            rtmpStream = RTMPStream(connection: rtmpConnection)
            srtStream = nil
            netStream = rtmpStream
        case .srt:
            srtStream = SRTStream(srtConnection)
            rtmpStream = nil
            netStream = srtStream
        }
        netStream.delegate = self
        netStream.videoOrientation = .landscapeRight
        attachAudio(device: AVCaptureDevice.default(for: .audio))
    }

    func getAudioLevel() -> Float {
        return currentAudioLevel
    }

    func srtStartStream(
        isSrtla: Bool,
        url: String,
        reconnectTime: Double,
        targetBitrate: UInt32,
        adaptiveBitrate adaptiveBitrateEnabled: Bool,
        latency: Int32,
        overheadBandwidth: Int32,
        mpegtsPacketsPerPacket: Int
    ) {
        srtUrl = url
        self.latency = latency
        self.overheadBandwidth = overheadBandwidth
        srtTotalByteCount = 0
        srtPreviousTotalByteCount = 0
        srtla?.stop()
        srtla = Srtla(
            delegate: self,
            passThrough: !isSrtla,
            mpegtsPacketsPerPacket: mpegtsPacketsPerPacket
        )
        if adaptiveBitrateEnabled {
            adaptiveBitrate = AdaptiveBitrate(
                targetBitrate: targetBitrate,
                delegate: self
            )
            if let dataRateLimits = [
                NSNumber(value: 15000 / 8 * 1024),
                NSNumber(value: 1),
            ] as? CFArray {
                netStream.videoSettings.extraOptions = [.init(
                    key: .dataRateLimits,
                    value: dataRateLimits
                )]
            } else {
                logger.error("Failed to cast initial data rate limits")
            }
        } else {
            adaptiveBitrate = nil
        }
        srtla!.start(uri: url, timeout: reconnectTime + 1)
    }

    func srtStopStream() {
        srtConnection.close()
        srtla?.stop()
        srtla = nil
        srtConnectedObservation = nil
        adaptiveBitrate = nil
    }

    func getSrtStats(overlay: Bool) -> [String]? {
        let stats = srtConnection.performanceData
        adaptiveBitrate?.update(stats: stats)
        guard overlay else {
            return nil
        }
        if let adapativeStats = adaptiveBitrate {
            return [
                "R: \(stats.pktRetransTotal) N: \(stats.pktRecvNAKTotal) S: \(stats.pktSndDropTotal)",
                "msRTT: \(stats.msRTT)",
                """
                pktFlightSize: \(stats.pktFlightSize)   \
                \(adapativeStats.GetFastPif)   \
                \(adapativeStats.GetSmoothPif)
                """,
                "B: \(adapativeStats.getCurrentBitrate) /  \(adapativeStats.getTempMaxBitrate)",
            ] + adapativeStats.getAdaptiveActions
        } else {
            return [
                "pktRetransTotal: \(stats.pktRetransTotal)",
                "pktRecvNAKTotal: \(stats.pktRecvNAKTotal)",
                "pktSndDropTotal: \(stats.pktSndDropTotal)",
                "msRTT: \(stats.msRTT)",
                "pktFlightSize: \(stats.pktFlightSize)",
                "pktSndBuf: \(stats.pktSndBuf)",
            ]
        }
    }

    func updateSrtSpeed() {
        srtTotalByteCount = srtla?.getTotalByteCount() ?? 0
        let byteCount = max(srtTotalByteCount - srtPreviousTotalByteCount, 0)
        srtSpeed = Int64(Double(srtSpeed) * 0.7 + Double(byteCount) * 0.3)
        srtPreviousTotalByteCount = srtTotalByteCount
    }

    func streamSpeed() -> Int64 {
        if netStream === rtmpStream {
            return Int64(8 * (rtmpStream?.info.currentBytesPerSecond ?? 0))
        } else {
            return 8 * srtSpeed
        }
    }

    func streamTotal() -> Int64 {
        if netStream === rtmpStream {
            return rtmpStream?.info.byteCount.value ?? 0
        } else {
            return srtTotalByteCount
        }
    }

    func setupSrtConnectionStateListener() {
        srtConnectedObservation = srtConnection.observe(\.connected, options: [
            .new,
            .old,
        ]) { [weak self] _, connected in
            guard let self else {
                return
            }
            DispatchQueue.main.async {
                if connected.newValue! {
                    self.onSrtConnected()
                } else {
                    self.onSrtDisconnected(String(localized: "SRT disconnected"))
                }
            }
        }
    }

    private func queryContains(queryItems: [URLQueryItem], name: String) -> Bool {
        return queryItems.contains(where: { parameter in parameter.name == name })
    }

    func makeLocalhostSrtUrl(
        url: String,
        port: UInt16,
        latency: Int32,
        overheadBandwidth: Int32
    ) -> URL? {
        guard let url = URL(string: url) else {
            return nil
        }
        guard let localUrl = URL(string: "srt://localhost:\(port)") else {
            return nil
        }
        var urlComponents = URLComponents(url: localUrl, resolvingAgainstBaseURL: false)!
        urlComponents.query = url.query
        var queryItems: [URLQueryItem] = urlComponents.queryItems ?? []
        if !queryContains(queryItems: queryItems, name: "latency") {
            logger.debug("Setting SRT latency to \(latency)")
            queryItems.append(URLQueryItem(name: "latency", value: String(latency)))
        }
        if !queryContains(queryItems: queryItems, name: "oheadbw") {
            logger.debug("Setting SRT oheadbw to \(overheadBandwidth)")
            queryItems.append(URLQueryItem(
                name: "oheadbw",
                value: String(overheadBandwidth)
            ))
        }
        urlComponents.queryItems = queryItems
        return urlComponents.url
    }

    func rtmpStartStream(url: String) {
        rtmpStreamName = makeRtmpStreamName(url: url)
        rtmpConnection.addEventListener(
            .rtmpStatus,
            selector: #selector(rtmpStatusHandler),
            observer: self
        )
        rtmpConnection.connect(makeRtmpUri(url: url))
    }

    func rtmpStopStream() {
        rtmpConnection.removeEventListener(
            .rtmpStatus,
            selector: #selector(rtmpStatusHandler),
            observer: self
        )
        rtmpStream?.close()
        rtmpConnection.close()
    }

    @objc
    private func rtmpStatusHandler(_ notification: Notification) {
        let e = Event.from(notification)
        guard let data: ASObject = e.data as? ASObject,
              let code: String = data["code"] as? String
        else {
            return
        }
        DispatchQueue.main.async {
            switch code {
            case RTMPConnection.Code.connectSuccess.rawValue:
                self.rtmpStream?.publish(self.rtmpStreamName)
                self.onRtmpConnected()
            case RTMPConnection.Code.connectFailed.rawValue,
                 RTMPConnection.Code.connectClosed.rawValue:
                self.onRtmpDisconnected("\(code)")
            default:
                break
            }
        }
    }

    func setTorch(on: Bool) {
        netStream.torch = on
    }

    func setMute(on: Bool) {
        netStream.hasAudio = !on
    }

    func registerEffect(_ effect: VideoEffect) {
        if !netStream.registerVideoEffect(effect) {
            logger.info("Failed to register video effect")
        }
    }

    func unregisterEffect(_ effect: VideoEffect) {
        _ = netStream.unregisterVideoEffect(effect)
    }

    func setVideoSessionPreset(preset: AVCaptureSession.Preset) {
        netStream.sessionPreset = preset
    }

    func setVideoSize(size: VideoSize) {
        netStream.videoSettings.videoSize = size
    }

    func getVideoSize() -> VideoSize {
        return netStream.videoSettings.videoSize
    }

    func setStreamFPS(fps: Int) {
        netStream.frameRate = Double(fps)
    }

    func setVideoStreamBitrate(bitrate: UInt32) {
        adaptiveBitrate?.setTargetBitrate(bitrate: bitrate)
        netStream.videoSettings.bitRate = bitrate
    }

    func setVideoProfile(profile: CFString) {
        netStream.videoSettings.profileLevel = profile as String
    }

    func setStreamKeyFrameInterval(seconds: Int32) {
        netStream.videoSettings.maxKeyFrameIntervalDuration = seconds
    }

    func setCameraZoomLevel(level: Float, rate: Float?) -> Float? {
        guard let device = netStream.videoCapture()?.device else {
            logger.warning("Device not ready to zoom")
            return nil
        }
        let level = level.clamped(to: 1.0 ... Float(device.activeFormat.videoMaxZoomFactor))
        do {
            try device.lockForConfiguration()
            if let rate {
                device.ramp(toVideoZoomFactor: CGFloat(level), withRate: rate)
            } else {
                device.videoZoomFactor = CGFloat(level)
            }
            device.unlockForConfiguration()
        } catch let error as NSError {
            logger.warning("While locking device for ramp: \(error)")
        }
        return level
    }

    func attachCamera(
        device: AVCaptureDevice?,
        secondDevice: AVCaptureDevice?,
        videoStabilizationMode: AVCaptureVideoStabilizationMode,
        onSuccess: (() -> Void)? = nil
    ) {
        netStream.videoCapture()?.preferredVideoStabilizationMode = videoStabilizationMode
        netStream.multiVideoCapture()?.preferredVideoStabilizationMode = videoStabilizationMode
        if let secondDevice {
            logger.info("Should use two cameras")
            if false {
                netStream.attachMultiCamera(secondDevice) { error in
                    logger.error("stream: second camera error: \(error)")
                }
            }
        } else {
            netStream.attachMultiCamera(nil) { error in
                logger.error("stream: remove second camera error: \(error)")
            }
        }
        netStream.attachCamera(device, onError: { error in
            logger.error("stream: Attach camera error: \(error)")
        }, onSuccess: {
            DispatchQueue.main.async {
                onSuccess?()
            }
        })
    }

    func attachAudio(device: AVCaptureDevice?) {
        netStream?.attachAudio(device) { error in
            logger.error("stream: Attach audio error: \(error)")
        }
    }

    func getNetStream() -> NetStream {
        return netStream
    }
}

extension Media: NetStreamDelegate {
    private func kind(_ netStream: NetStream) -> String {
        if (netStream as? RTMPStream) != nil {
            return "RTMP"
        } else if (netStream as? SRTStream) != nil {
            return "SRT"
        } else {
            return "Unknown"
        }
    }

    func stream(
        _ netStream: NetStream,
        sessionWasInterrupted _: AVCaptureSession,
        reason: AVCaptureSession.InterruptionReason?
    ) {
        if let reason {
            logger
                .info(
                    "stream: \(kind(netStream)): Session was interrupted with reason: \(reason.toString())"
                )
            if reason == .videoDeviceInUseByAnotherClient {
                onVideoDeviceInUseByAnotherClient()
            }
        } else {
            logger
                .info(
                    "stream: \(kind(netStream)): Session was interrupted without reason"
                )
        }
    }

    func stream(_ netStream: NetStream, sessionInterruptionEnded _: AVCaptureSession) {
        logger.info("stream: \(kind(netStream)): Session interrupted ended.")
    }

    func stream(_ netStream: NetStream, videoCodecErrorOccurred error: VideoCodec.Error) {
        logger.error("stream: \(kind(netStream)): Video codec error: \(error)")
    }

    func stream(_ netStream: NetStream,
                audioCodecErrorOccurred error: HaishinKit.AudioCodec.Error)
    {
        logger.error("stream: \(kind(netStream)): Audio codec error: \(error)")
    }

    func streamWillDropFrame(_: NetStream) -> Bool {
        return false
    }

    func streamDidOpen(_: NetStream) {}

    func stream(
        _: NetStream,
        audioLevel: Float,
        numberOfChannels: Int,
        numberOfSamples: Int,
        stride _: Int
    ) {
        DispatchQueue.main.async {
            self.numberOfAudioChannels = numberOfChannels
            self.numberOfAudioSamples = numberOfSamples
            if becameMuted(old: self.currentAudioLevel, new: audioLevel) || becameUnmuted(
                old: self.currentAudioLevel,
                new: audioLevel
            ) {
                self.currentAudioLevel = audioLevel
                self.onAudioMuteChange()
            } else {
                self.currentAudioLevel = audioLevel
            }
        }
    }
}

extension Media: SrtlaDelegate {
    func srtlaReady(port: UInt16) {
        DispatchQueue.main.async {
            self.setupSrtConnectionStateListener()
            mediaDispatchQueue.async {
                do {
                    try self.srtConnection.open(self.makeLocalhostSrtUrl(
                        url: self.srtUrl,
                        port: port,
                        latency: self.latency,
                        overheadBandwidth: self.overheadBandwidth
                    )) { data in
                        if let srtla = self.srtla {
                            srtlaDispatchQueue.async {
                                srtla.handleLocalPacket(packet: data)
                            }
                        }
                        return true
                    }
                    self.srtStream?.publish()
                } catch {
                    DispatchQueue.main.async {
                        self
                            .onSrtDisconnected(
                                String(localized: "SRT connect failed with \(error.localizedDescription)")
                            )
                    }
                }
            }
        }
    }

    func srtlaError(message: String) {
        DispatchQueue.main.async {
            logger.info("stream: SRT error: \(message)")
            self.onSrtDisconnected(String(localized: "SRT error: \(message)"))
        }
    }
}

extension Media: AdaptiveBitrateDelegate {
    func adaptiveBitrateSetVideoStreamBitrate(bitrate: UInt32) {
        netStream.videoSettings.bitRate = bitrate
    }
}
