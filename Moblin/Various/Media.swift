import AVFoundation
import HaishinKit

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
    private var currentAudioLevel: Float = -160.0
    private var numberOfAudioChannels: Int = 0
    private var audioCapturePresentationTimestamp: Double = 0
    private var videoCapturePresentationTimestamp: Double = 0
    private var srtUrl: String = ""
    private var latency: Int32 = 2000
    private var overheadBandwidth: Int32 = 25
    private var maximumBandwidthFollowInput: Bool = false
    var onSrtConnected: (() -> Void)!
    var onSrtDisconnected: ((_ reason: String) -> Void)!
    var onRtmpConnected: (() -> Void)!
    var onRtmpDisconnected: ((_ message: String) -> Void)!
    var onAudioMuteChange: (() -> Void)!
    var onVideoDeviceInUseByAnotherClient: (() -> Void)!
    private var adaptiveBitrate: AdaptiveBitrate?
    private var failedVideoEffect: String?

    func logStatistics() {
        srtla?.logStatistics()
    }

    func srtlaConnectionStatistics() -> String? {
        return srtla?.connectionStatistics() ?? nil
    }

    func setConnectionPriorities(connectionPriorities: SettingsStreamSrtConnectionPriorities) {
        srtla?.setConnectionPriorities(connectionPriorities: connectionPriorities)
    }

    func setAdaptiveBitrateAlgorithm(settings: AdaptiveBitrateSettings) {
        adaptiveBitrate?.setSettings(settings: settings)
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

    func getNumberOfAudioChannels() -> Int {
        return numberOfAudioChannels
    }

    func getAudioCapturePresentationTimestamp() -> Double {
        return audioCapturePresentationTimestamp
    }

    func getVideoCapturePresentationTimestamp() -> Double {
        return videoCapturePresentationTimestamp
    }

    func getCaptureDelta() -> Double {
        return audioCapturePresentationTimestamp - videoCapturePresentationTimestamp
    }

    func logTiming() {
        let audioPts = getAudioCapturePresentationTimestamp()
        let videoPts = getVideoCapturePresentationTimestamp()
        let delta = getCaptureDelta()
        logger.debug("CapturePts: audio: \(audioPts), video: \(videoPts), delta: \(delta)")
        logger.debug("""
        CapturePts: audio: \(CMClock.hostTimeClock.time.seconds - audioPts), \
        video: \(CMClock.hostTimeClock.time.seconds - videoPts)
        """)
        let audioClock = netStream.mixer.audioSession.synchronizationClock!
        let videoClock = netStream.mixer.captureSession.synchronizationClock!
        let audioRate = CMClock.hostTimeClock.rate(relativeTo: audioClock)
        let videoRate = CMClock.hostTimeClock.rate(relativeTo: videoClock)
        logger.debug("""
        CapturePts: rate: audio: \(audioRate) video: \(videoRate) \
        h: \(CMClock.hostTimeClock.time.seconds) a: \(audioClock.time.seconds) \
        v: \(videoClock.time.seconds)
        """)
    }

    func srtStartStream(
        isSrtla: Bool,
        url: String,
        reconnectTime: Double,
        targetBitrate: UInt32,
        adaptiveBitrate adaptiveBitrateEnabled: Bool,
        latency: Int32,
        overheadBandwidth: Int32,
        maximumBandwidthFollowInput: Bool,
        mpegtsPacketsPerPacket: Int,
        networkInterfaceNames: [SettingsNetworkInterfaceName],
        connectionPriorities: SettingsStreamSrtConnectionPriorities
    ) {
        srtUrl = url
        self.latency = latency
        self.overheadBandwidth = overheadBandwidth
        self.maximumBandwidthFollowInput = maximumBandwidthFollowInput
        srtTotalByteCount = 0
        srtPreviousTotalByteCount = 0
        srtla?.stop()
        srtla = Srtla(
            delegate: self,
            passThrough: !isSrtla,
            mpegtsPacketsPerPacket: mpegtsPacketsPerPacket,
            networkInterfaceNames: networkInterfaceNames,
            connectionPriorities: connectionPriorities
        )
        if adaptiveBitrateEnabled {
            adaptiveBitrate = AdaptiveBitrate(
                targetBitrate: targetBitrate,
                delegate: self
            )
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

    func setNetworkInterfaceNames(networkInterfaceNames: [SettingsNetworkInterfaceName]) {
        srtla?.setNetworkInterfaceNames(networkInterfaceNames: networkInterfaceNames)
    }

    func updateAdaptiveBitrate(overlay: Bool) -> [String]? {
        if srtStream != nil {
            let stats = srtConnection.performanceData
            adaptiveBitrate?.update(stats: StreamStats(
                rttMs: stats.msRTT,
                packetsInFlight: Double(stats.pktFlightSize)
            ))
            guard overlay else {
                return nil
            }
            if let adaptiveBitrate {
                return [
                    "R: \(stats.pktRetransTotal) N: \(stats.pktRecvNAKTotal) S: \(stats.pktSndDropTotal)",
                    "msRTT: \(stats.msRTT)",
                    """
                    pktFlightSize: \(stats.pktFlightSize)   \
                    \(adaptiveBitrate.getFastPif)   \
                    \(adaptiveBitrate.getSmoothPif)
                    """,
                    "B: \(adaptiveBitrate.getCurrentBitrate) /  \(adaptiveBitrate.getTempMaxBitrate)",
                ] + adaptiveBitrate.getAdaptiveActions
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
        } else if let rtmpStream {
            let stats = rtmpStream.info.stats.value
            adaptiveBitrate?.update(stats: StreamStats(
                rttMs: stats.rttMs,
                packetsInFlight: Double(stats.packetsInFlight)
            ))
            guard overlay else {
                return nil
            }
            if let adaptiveBitrate {
                return [
                    "rttMs: \(stats.rttMs)",
                    """
                    packetsInFlight: \(stats.packetsInFlight)   \
                    \(adaptiveBitrate.getFastPif)   \
                    \(adaptiveBitrate.getSmoothPif)
                    """,
                    "B: \(adaptiveBitrate.getCurrentBitrate) /  \(adaptiveBitrate.getTempMaxBitrate)",
                ] + adaptiveBitrate.getAdaptiveActions
            } else {
                return [
                    "rttMs: \(stats.rttMs)",
                    "packetsInFlight: \(stats.packetsInFlight)",
                ]
            }
        }
        return nil
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
        overheadBandwidth: Int32,
        maximumBandwidthFollowInput: Bool
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
            logger.info("Setting SRT latency to \(latency)")
            queryItems.append(URLQueryItem(name: "latency", value: String(latency)))
        }
        if !queryContains(queryItems: queryItems, name: "maxbw") {
            if maximumBandwidthFollowInput {
                logger.info("Setting SRT maxbw to 0 (follows input)")
                queryItems.append(URLQueryItem(name: "maxbw", value: "0"))
            }
        }
        if !queryContains(queryItems: queryItems, name: "oheadbw") {
            logger.info("Setting SRT oheadbw to \(overheadBandwidth)")
            queryItems.append(URLQueryItem(
                name: "oheadbw",
                value: String(overheadBandwidth)
            ))
        }
        urlComponents.queryItems = queryItems
        return urlComponents.url
    }

    func rtmpStartStream(url: String,
                         targetBitrate: UInt32,
                         adaptiveBitrate adaptiveBitrateEnabled: Bool)
    {
        rtmpStreamName = makeRtmpStreamName(url: url)
        rtmpConnection.addEventListener(
            .rtmpStatus,
            selector: #selector(rtmpStatusHandler),
            observer: self
        )
        if adaptiveBitrateEnabled {
            adaptiveBitrate = AdaptiveBitrate(
                targetBitrate: targetBitrate,
                delegate: self
            )
        } else {
            adaptiveBitrate = nil
        }
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
        adaptiveBitrate = nil
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
            logger.debug("Failed to register video effect")
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

    func getVideoSize() -> CGSize {
        let size = netStream.videoSettings.videoSize
        return CGSize(width: CGFloat(size.width), height: CGFloat(size.height))
    }

    func setStreamFPS(fps: Int) {
        netStream.frameRate = Double(fps)
    }

    func setColorSpace(colorSpace: AVCaptureColorSpace, onComplete: @escaping () -> Void) {
        netStream.setColorSpace(colorSpace: colorSpace, onComplete: onComplete)
    }

    private var multiplier: UInt32 = 0

    func updateVideoStreamBitrate(bitrate: UInt32) {
        multiplier ^= 1
        var bitRate: UInt32
        if let adaptiveBitrate {
            bitRate = UInt32(1000 * adaptiveBitrate.getCurrentBitrate)
        } else {
            bitRate = bitrate
        }
        netStream.videoSettings.bitRate = bitRate + multiplier * (bitRate / 10)
    }

    func setVideoStreamBitrate(bitrate: UInt32) {
        adaptiveBitrate?.setTargetBitrate(bitrate: bitrate)
        netStream.videoSettings.bitRate = bitrate
    }

    func setVideoProfile(profile: CFString) {
        netStream.videoSettings.profileLevel = profile as String
    }

    func setAllowFrameReordering(value: Bool) {
        netStream.videoSettings.allowFrameReordering = value
    }

    func setStreamKeyFrameInterval(seconds: Int32) {
        netStream.videoSettings.maxKeyFrameIntervalDuration = seconds
    }

    func setAudioStreamBitrate(bitrate: Int) {
        netStream.audioSettings.bitRate = bitrate
    }

    func setAudioChannelsMap(channelsMap: [Int: Int]) {
        netStream.audioSettings.outputChannelsMap = channelsMap
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

    func stopCameraZoomLevel() -> Float? {
        guard let device = netStream.videoCapture()?.device else {
            logger.warning("Device not ready to zoom")
            return nil
        }
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = device.videoZoomFactor
            device.unlockForConfiguration()
        } catch let error as NSError {
            logger.warning("While locking device for stop: \(error)")
        }
        return Float(device.videoZoomFactor)
    }

    func attachCamera(
        device: AVCaptureDevice?,
        secondDevice _: AVCaptureDevice?,
        videoStabilizationMode: AVCaptureVideoStabilizationMode,
        videoMirrored: Bool,
        onSuccess: (() -> Void)? = nil
    ) {
        netStream.videoCapture()?.preferredVideoStabilizationMode = videoStabilizationMode
        netStream.videoCapture()?.isVideoMirrored = videoMirrored
        netStream.attachCamera(device, onError: { error in
            logger.error("stream: Attach camera error: \(error)")
        }, onSuccess: {
            DispatchQueue.main.async {
                onSuccess?()
            }
        })
    }

    func attachRtmpCamera(cameraId: UUID, device: AVCaptureDevice?) {
        netStream.attachCamera(device, replaceVideoCameraId: cameraId)
    }

    func addRtmpSampleBuffer(cameraId: UUID, sampleBuffer: CMSampleBuffer) {
        netStream.addReplaceVideoSampleBuffer(id: cameraId, sampleBuffer)
    }

    func addRtmpCamera(cameraId: UUID, latency: Double) {
        netStream.addReplaceVideo(cameraId: cameraId, latency: latency)
    }

    func removeRtmpCamera(cameraId: UUID) {
        netStream.removeReplaceVideo(cameraId: cameraId)
    }

    func attachAudio(device: AVCaptureDevice?) {
        netStream?.attachAudio(device) { error in
            logger.error("stream: Attach audio error: \(error)")
        }
    }

    func getNetStream() -> NetStream {
        return netStream
    }

    func startRecording(
        url: URL,
        videoCodec: SettingsStreamCodec,
        videoBitrate: Int? = nil,
        keyFrameInterval: Int? = nil
    ) {
        var codec: AVVideoCodecType
        switch videoCodec {
        case .h264avc:
            codec = AVVideoCodecType.h264
        case .h265hevc:
            codec = AVVideoCodecType.hevc
        }
        var videoProperties: [String: Any] = [
            AVVideoCodecKey: codec,
            AVVideoHeightKey: 0,
            AVVideoWidthKey: 0,
        ]
        var compressionProperties: [String: Any] = [:]
        if let videoBitrate {
            compressionProperties[AVVideoAverageBitRateKey] = videoBitrate
        }
        if let keyFrameInterval {
            compressionProperties[AVVideoMaxKeyFrameIntervalDurationKey] = keyFrameInterval
        }
        if !compressionProperties.isEmpty {
            videoProperties[AVVideoCompressionPropertiesKey] = compressionProperties
        }
        netStream.startRecording(url: url, [
            .audio: [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 0,
                AVNumberOfChannelsKey: 0,
            ],
            .video: videoProperties,
        ])
    }

    func stopRecording() {
        netStream.stopRecording()
    }

    func getFailedVideoEffect() -> String? {
        return failedVideoEffect
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

    func stream(_: NetStream, audioLevel: Float, numberOfAudioChannels: Int, presentationTimestamp: Double) {
        DispatchQueue.main.async {
            if becameMuted(old: self.currentAudioLevel, new: audioLevel) || becameUnmuted(
                old: self.currentAudioLevel,
                new: audioLevel
            ) {
                self.currentAudioLevel = audioLevel
                self.onAudioMuteChange()
            } else {
                self.currentAudioLevel = audioLevel
            }
            self.numberOfAudioChannels = numberOfAudioChannels
            self.audioCapturePresentationTimestamp = presentationTimestamp
        }
    }

    func streamVideo(_: HaishinKit.NetStream, presentationTimestamp: Double) {
        DispatchQueue.main.async {
            self.videoCapturePresentationTimestamp = presentationTimestamp
        }
    }

    func streamVideo(_: HaishinKit.NetStream, failedEffect: String?) {
        DispatchQueue.main.async {
            self.failedVideoEffect = failedEffect
        }
    }

    func stream(_: HaishinKit.NetStream, recorderErrorOccured error: HaishinKit.IORecorder.Error) {
        logger.info("stream: Recording failed with \(error)")
    }

    func stream(_: HaishinKit.NetStream, recorderFinishWriting _: AVAssetWriter) {
        logger.info("stream: Recording finished")
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
                        overheadBandwidth: self.overheadBandwidth,
                        maximumBandwidthFollowInput: self.maximumBandwidthFollowInput
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
