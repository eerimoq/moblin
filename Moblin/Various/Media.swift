import AVFoundation
import SwiftUI

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
    private var ristStream: RistStream?
    private var irlStream: IrlStream?
    private var srtlaClient: SrtlaClient?
    private var netStream: NetStream?
    private var srtTotalByteCount: Int64 = 0
    private var srtPreviousTotalByteCount: Int64 = 0
    private var srtSpeed: Int64 = 0
    private var srtConnectedObservation: NSKeyValueObservation?
    private var rtmpStreamName = ""
    private var currentAudioLevel: Float = defaultAudioLevel
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
    var onRistConnected: (() -> Void)!
    var onRistDisconnected: (() -> Void)!
    var onAudioMuteChange: (() -> Void)!
    var onAudioBuffer: ((CMSampleBuffer) -> Void)!
    var onLowFpsImage: ((Data?, UInt64) -> Void)!
    var onFindVideoFormatError: ((String, String) -> Void)!
    var onNoTorch: (() -> Void)!
    private var adaptiveBitrate: AdaptiveBitrate?
    private var failedVideoEffect: String?
    private var irlToolkitFetcher: IrlToolkitFetcher?
    var srtDroppedPacketsTotal: Int32 = 0

    func logStatistics() {
        srtlaClient?.logStatistics()
    }

    func srtlaConnectionStatistics() -> [BondingConnection]? {
        return srtlaClient?.connectionStatistics()
    }

    func ristBondingStatistics() -> [BondingConnection]? {
        return ristStream?.connectionStatistics()
    }

    func setConnectionPriorities(connectionPriorities: SettingsStreamSrtConnectionPriorities) {
        srtlaClient?.setConnectionPriorities(connectionPriorities: connectionPriorities)
    }

    func setAdaptiveBitrateSettings(settings: AdaptiveBitrateSettings) {
        adaptiveBitrate?.setSettings(settings: settings)
    }

    func stopAllNetStreams() {
        rtmpConnection = RTMPConnection()
        srtStopStream()
        rtmpStopStream()
        ristStopStream()
        irlStopStream()
        rtmpStream = nil
        srtStream = nil
        ristStream = nil
        irlStream = nil
        netStream = nil
    }

    func setNetStream(proto: SettingsStreamProtocol) {
        netStream?.stopMixer()
        srtStopStream()
        rtmpStopStream()
        ristStopStream()
        irlStopStream()
        rtmpConnection = RTMPConnection()
        switch proto {
        case .rtmp:
            rtmpStream = RTMPStream(connection: rtmpConnection)
            srtStream = nil
            ristStream = nil
            irlStream = nil
            netStream = rtmpStream
        case .srt, .irltk:
            srtStream = SRTStream(srtConnection)
            rtmpStream = nil
            ristStream = nil
            irlStream = nil
            netStream = srtStream
        case .rist:
            ristStream = RistStream()
            ristStream?.onConnected = onRistConnected
            ristStream?.onDisconnected = onRistDisconnected
            srtStream = nil
            rtmpStream = nil
            irlStream = nil
            netStream = ristStream
        case .irl:
            irlStream = IrlStream()
            srtStream = nil
            rtmpStream = nil
            ristStream = nil
            netStream = irlStream
        }
        netStream!.delegate = self
        netStream!.setVideoOrientation(value: .landscapeRight)
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
        if let audioClock = netStream?.mixer.audio.session.synchronizationClock,
           let videoClock = netStream?.mixer.video.session.synchronizationClock
        {
            let audioRate = CMClock.hostTimeClock.rate(relativeTo: audioClock)
            let videoRate = CMClock.hostTimeClock.rate(relativeTo: videoClock)
            logger.debug("""
            CapturePts: rate: audio: \(audioRate) video: \(videoRate) \
            h: \(CMClock.hostTimeClock.time.seconds) a: \(audioClock.time.seconds) \
            v: \(videoClock.time.seconds)
            """)
        }
    }

    func srtStartStream(
        isSrtla: Bool,
        url: String,
        reconnectTime: Double,
        targetBitrate: UInt32,
        adaptiveBitrateAlgorithm: SettingsStreamSrtAdaptiveBitrateAlgorithm?,
        latency: Int32,
        overheadBandwidth: Int32,
        maximumBandwidthFollowInput: Bool,
        mpegtsPacketsPerPacket: Int,
        networkInterfaceNames: [SettingsNetworkInterfaceName],
        connectionPriorities: SettingsStreamSrtConnectionPriorities
    ) {
        srtUrl = url
        srtInitStream(
            isSrtla: isSrtla,
            targetBitrate: targetBitrate,
            adaptiveBitrateAlgorithm: adaptiveBitrateAlgorithm,
            latency: latency,
            overheadBandwidth: overheadBandwidth,
            maximumBandwidthFollowInput: maximumBandwidthFollowInput,
            mpegtsPacketsPerPacket: mpegtsPacketsPerPacket,
            networkInterfaceNames: networkInterfaceNames,
            connectionPriorities: connectionPriorities
        )
        srtlaClient!.start(uri: url, timeout: reconnectTime + 1)
    }

    private func srtInitStream(
        isSrtla: Bool,
        targetBitrate: UInt32,
        adaptiveBitrateAlgorithm: SettingsStreamSrtAdaptiveBitrateAlgorithm?,
        latency: Int32,
        overheadBandwidth: Int32,
        maximumBandwidthFollowInput: Bool,
        mpegtsPacketsPerPacket: Int,
        networkInterfaceNames: [SettingsNetworkInterfaceName],
        connectionPriorities: SettingsStreamSrtConnectionPriorities
    ) {
        self.latency = latency
        self.overheadBandwidth = overheadBandwidth
        self.maximumBandwidthFollowInput = maximumBandwidthFollowInput
        srtTotalByteCount = 0
        srtPreviousTotalByteCount = 0
        srtDroppedPacketsTotal = 0
        srtlaClient?.stop()
        srtlaClient = SrtlaClient(
            delegate: self,
            passThrough: !isSrtla,
            mpegtsPacketsPerPacket: mpegtsPacketsPerPacket,
            networkInterfaceNames: networkInterfaceNames,
            connectionPriorities: connectionPriorities
        )
        switch adaptiveBitrateAlgorithm {
        case .fastIrl, .slowIrl, .customIrl:
            adaptiveBitrate = AdaptiveBitrateSrtFight(targetBitrate: targetBitrate, delegate: self)
        case .belabox:
            adaptiveBitrate = AdaptiveBitrateSrtBela(targetBitrate: targetBitrate, delegate: self)
        case nil:
            adaptiveBitrate = nil
        }
    }

    func srtStopStream() {
        srtConnection.close()
        srtlaClient?.stop()
        srtlaClient = nil
        srtConnectedObservation = nil
        adaptiveBitrate = nil
    }

    func setNetworkInterfaceNames(networkInterfaceNames: [SettingsNetworkInterfaceName]) {
        srtlaClient?.setNetworkInterfaceNames(networkInterfaceNames: networkInterfaceNames)
    }

    private var updateTickCount: UInt64 = 0

    private func is200MsTick() -> Bool {
        return updateTickCount % 10 == 0
    }

    func updateAdaptiveBitrate(overlay: Bool) -> ([String], [String])? {
        updateTickCount += 1
        if srtStream != nil {
            return updateAdaptiveBitrateSrt(overlay: overlay)
        } else if let rtmpStream {
            return updateAdaptiveBitrateRtmp(overlay: overlay, rtmpStream: rtmpStream)
        } else if let ristStream {
            return updateAdaptiveBitrateRist(overlay: overlay, ristStream: ristStream)
        }
        return nil
    }

    private func updateAdaptiveBitrateSrt(overlay: Bool) -> ([String], [String])? {
        if adaptiveBitrate is AdaptiveBitrateSrtBela {
            return updateAdaptiveBitrateSrtBela(overlay: overlay)
        } else {
            return updateAdaptiveBitrateSrtFight(overlay: overlay)
        }
    }

    private var belaLinesAndActions: ([String], [String])?

    private func updateAdaptiveBitrateSrtBela(overlay: Bool) -> ([String], [String])? {
        let stats = srtConnection.performanceData
        srtDroppedPacketsTotal = stats.pktSndDropTotal
        guard let adaptiveBitrate else {
            return nil
        }
        let sndData = srtConnection.socket?.sndData() ?? 0
        adaptiveBitrate.update(stats: StreamStats(
            rttMs: stats.msRTT,
            packetsInFlight: Double(sndData),
            transportBitrate: streamSpeed(),
            latency: latency,
            mbpsSendRate: stats.mbpsSendRate
        ))
        if overlay {
            if is200MsTick() {
                belaLinesAndActions = ([
                    """
                    R: \(stats.pktRetransTotal) N: \(stats.pktRecvNAKTotal) \
                    D: \(stats.pktSndDropTotal) E: \(numberOfFailedEncodings)
                    """,
                    "msRTT: \(stats.msRTT)",
                    "sndData: \(sndData)",
                    "B: \(adaptiveBitrate.getCurrentBitrateInKbps())",
                ], adaptiveBitrate.getActionsTaken())
            }
        } else {
            belaLinesAndActions = nil
        }
        return belaLinesAndActions
    }

    private func updateAdaptiveBitrateSrtFight(overlay: Bool) -> ([String], [String])? {
        guard is200MsTick() else {
            return nil
        }
        let stats = srtConnection.performanceData
        srtDroppedPacketsTotal = stats.pktSndDropTotal
        adaptiveBitrate?.update(stats: StreamStats(
            rttMs: stats.msRTT,
            packetsInFlight: Double(stats.pktFlightSize),
            transportBitrate: streamSpeed(),
            latency: latency,
            mbpsSendRate: stats.mbpsSendRate
        ))
        guard overlay else {
            return nil
        }
        if let adaptiveBitrate {
            return ([
                """
                R: \(stats.pktRetransTotal) N: \(stats.pktRecvNAKTotal) \
                D: \(stats.pktSndDropTotal) E: \(numberOfFailedEncodings)
                """,
                "msRTT: \(stats.msRTT)",
                """
                pktFlightSize: \(stats.pktFlightSize)   \
                \(adaptiveBitrate.getFastPif())   \
                \(adaptiveBitrate.getSmoothPif())
                """,
                """
                B: \(adaptiveBitrate.getCurrentBitrateInKbps()) /  \
                \(adaptiveBitrate.getCurrentMaximumBitrateInKbps())
                """,
            ], adaptiveBitrate.getActionsTaken())
        } else {
            return ([
                "pktRetransTotal: \(stats.pktRetransTotal)",
                "pktRecvNAKTotal: \(stats.pktRecvNAKTotal)",
                "pktSndDropTotal: \(stats.pktSndDropTotal)",
                "msRTT: \(stats.msRTT)",
                "pktFlightSize: \(stats.pktFlightSize)",
                "pktSndBuf: \(stats.pktSndBuf)",
            ], [])
        }
    }

    private func updateAdaptiveBitrateRtmp(overlay: Bool, rtmpStream: RTMPStream) -> ([String], [String])? {
        guard is200MsTick() else {
            return nil
        }
        let stats = rtmpStream.info.stats.value
        adaptiveBitrate?.update(stats: StreamStats(
            rttMs: stats.rttMs,
            packetsInFlight: Double(stats.packetsInFlight),
            transportBitrate: streamSpeed(),
            latency: nil,
            mbpsSendRate: nil
        ))
        guard overlay else {
            return nil
        }
        if let adaptiveBitrate {
            return ([
                "rttMs: \(stats.rttMs)",
                """
                packetsInFlight: \(stats.packetsInFlight)   \
                \(adaptiveBitrate.getFastPif())   \
                \(adaptiveBitrate.getSmoothPif())
                """,
                """
                B: \(adaptiveBitrate.getCurrentBitrateInKbps()) /  \
                \(adaptiveBitrate.getCurrentMaximumBitrateInKbps())
                """,
            ], adaptiveBitrate.getActionsTaken())
        } else {
            return ([
                "rttMs: \(stats.rttMs)",
                "packetsInFlight: \(stats.packetsInFlight)",
            ], [])
        }
    }

    private func updateAdaptiveBitrateRist(overlay: Bool, ristStream: RistStream) -> ([String], [String])? {
        guard is200MsTick() else {
            return nil
        }
        let stats = ristStream.getStats()
        var rtt = 1000.0
        for stat in stats {
            rtt = min(rtt, Double(stat.rtt))
        }
        adaptiveBitrate?.update(stats: StreamStats(
            rttMs: rtt,
            packetsInFlight: 10,
            transportBitrate: nil,
            latency: nil,
            mbpsSendRate: nil
        ))
        ristStream.updateConnectionsWeights()
        guard overlay else {
            return nil
        }
        if let adaptiveBitrate {
            return ([
                "rttMs: \(rtt)",
                """
                \(adaptiveBitrate.getFastPif())   \
                \(adaptiveBitrate.getSmoothPif())
                """,
                """
                B: \(adaptiveBitrate.getCurrentBitrateInKbps()) /  \
                \(adaptiveBitrate.getCurrentMaximumBitrateInKbps())
                """,
            ], adaptiveBitrate.getActionsTaken())
        } else {
            return ([
                "rttMs: \(rtt)",
            ], [])
        }
    }

    func updateSrtSpeed() {
        srtTotalByteCount = srtlaClient?.getTotalByteCount() ?? 0
        let byteCount = max(srtTotalByteCount - srtPreviousTotalByteCount, 0)
        srtSpeed = Int64(Double(srtSpeed) * 0.7 + Double(byteCount) * 0.3)
        srtPreviousTotalByteCount = srtTotalByteCount
    }

    func streamSpeed() -> Int64 {
        if netStream === rtmpStream {
            return Int64(8 * (rtmpStream?.info.currentBytesPerSecond ?? 0))
        } else if netStream === srtStream {
            return 8 * srtSpeed
        } else if netStream === ristStream {
            return Int64(ristStream?.getSpeed() ?? 0)
        } else {
            return 0
        }
    }

    func streamTotal() -> Int64 {
        if netStream === rtmpStream {
            return rtmpStream?.info.byteCount.value ?? 0
        } else if netStream === srtStream {
            return srtTotalByteCount
        } else if netStream === ristStream {
            return 0
        } else {
            return 0
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
            adaptiveBitrate = AdaptiveBitrateSrtFight(
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
            switch RTMPConnection.Code(rawValue: code) {
            case .connectSuccess:
                self.rtmpStream?.publish(self.rtmpStreamName)
                self.onRtmpConnected()
            case .connectFailed, .connectClosed:
                self.onRtmpDisconnected("\(code)")
            default:
                break
            }
        }
    }

    func ristStartStream(
        url: String,
        bonding: Bool,
        targetBitrate: UInt32,
        adaptiveBitrate adaptiveBitrateEnabled: Bool
    ) {
        if adaptiveBitrateEnabled {
            adaptiveBitrate = AdaptiveBitrateRistExperiment(
                targetBitrate: targetBitrate,
                delegate: self
            )
        } else {
            adaptiveBitrate = nil
        }
        ristStream?.start(url: url, bonding: bonding)
    }

    func ristStopStream() {
        ristStream?.stop()
    }

    func irlStartStream() {
        irlStream?.start()
    }

    func irlStopStream() {
        irlStream?.stop()
    }

    func irlToolkitStartStream(
        url: String,
        reconnectTime: Double,
        targetBitrate: UInt32,
        adaptiveBitrateAlgorithm: SettingsStreamSrtAdaptiveBitrateAlgorithm?,
        latency: Int32,
        overheadBandwidth: Int32,
        maximumBandwidthFollowInput: Bool,
        mpegtsPacketsPerPacket: Int,
        networkInterfaceNames: [SettingsNetworkInterfaceName],
        connectionPriorities: SettingsStreamSrtConnectionPriorities
    ) {
        srtInitStream(
            isSrtla: true,
            targetBitrate: targetBitrate,
            adaptiveBitrateAlgorithm: adaptiveBitrateAlgorithm,
            latency: latency,
            overheadBandwidth: overheadBandwidth,
            maximumBandwidthFollowInput: maximumBandwidthFollowInput,
            mpegtsPacketsPerPacket: mpegtsPacketsPerPacket,
            networkInterfaceNames: networkInterfaceNames,
            connectionPriorities: connectionPriorities
        )
        irlToolkitFetcher?.stop()
        irlToolkitFetcher = IrlToolkitFetcher(url: url, timeout: reconnectTime)
        irlToolkitFetcher?.delegate = self
        irlToolkitFetcher?.start()
    }

    func irlToolkitStopStream() {
        irlToolkitFetcher?.stop()
        irlToolkitFetcher = nil
        srtStopStream()
    }

    func setTorch(on: Bool) {
        netStream?.setTorch(value: on)
    }

    func setMute(on: Bool) {
        netStream?.setHasAudio(value: !on)
    }

    func registerEffect(_ effect: VideoEffect) {
        netStream?.registerVideoEffect(effect)
    }

    func unregisterEffect(_ effect: VideoEffect) {
        netStream?.unregisterVideoEffect(effect)
    }

    func setPendingAfterAttachEffects(effects: [VideoEffect]) {
        netStream?.setPendingAfterAttachEffects(effects: effects)
    }

    func usePendingAfterAttachEffects() {
        netStream?.usePendingAfterAttachEffects()
    }

    func setLowFpsImage(fps: Float) {
        netStream?.setLowFpsImage(fps: fps)
    }

    func takeSnapshot(onComplete: @escaping (UIImage) -> Void) {
        netStream?.takeSnapshot(onComplete: onComplete)
    }

    func setVideoSize(capture: CGSize, output: CGSize) {
        netStream?.setVideoSize(capture: capture, output: output)
        netStream?.videoEncodecSettings.videoSize = .init(
            width: Int32(output.width),
            height: Int32(output.height)
        )
    }

    func getVideoSize() -> CGSize {
        guard let size = netStream?.videoEncodecSettings.videoSize else {
            return .init(width: 1920, height: 1080)
        }
        return CGSize(width: CGFloat(size.width), height: CGFloat(size.height))
    }

    func setStreamFPS(fps: Int) {
        netStream?.setFrameRate(value: Double(fps))
    }

    func setColorSpace(colorSpace: AVCaptureColorSpace, onComplete: @escaping () -> Void) {
        netStream?.setColorSpace(colorSpace: colorSpace, onComplete: onComplete)
    }

    private var multiplier: UInt32 = 0

    func updateVideoStreamBitrate(bitrate: UInt32) {
        multiplier ^= 1
        let bitRate = getVideoStreamBitrate(bitrate: bitrate)
        netStream?.videoEncodecSettings.bitRate = bitRate + multiplier * (bitRate / 10)
    }

    func getVideoStreamBitrate(bitrate: UInt32) -> UInt32 {
        var bitRate: UInt32
        if let adaptiveBitrate {
            bitRate = adaptiveBitrate.getCurrentBitrate()
        } else {
            bitRate = bitrate
        }
        return bitRate
    }

    func setVideoStreamBitrate(bitrate: UInt32) {
        adaptiveBitrate?.setTargetBitrate(bitrate: bitrate)
        netStream?.videoEncodecSettings.bitRate = bitrate
    }

    func setVideoProfile(profile: CFString) {
        netStream?.videoEncodecSettings.profileLevel = profile as String
    }

    func setAllowFrameReordering(value: Bool) {
        netStream?.videoEncodecSettings.allowFrameReordering = value
    }

    func setStreamKeyFrameInterval(seconds: Int32) {
        netStream?.videoEncodecSettings.maxKeyFrameIntervalDuration = seconds
    }

    func setStreamAdaptiveResolution(value: Bool) {
        netStream?.videoEncodecSettings.adaptiveResolution = value
    }

    func setStreamAdaptiveFps(value: Bool) {
        netStream?.videoEncodecSettings.adaptiveFps = value
    }

    func setAudioStreamBitrate(bitrate: Int) {
        netStream?.audioSettings.bitRate = bitrate
    }

    func setAudioStreamFormat(format: AudioCodecOutputSettings.Format) {
        netStream?.audioSettings.format = format
    }

    func setAudioChannelsMap(channelsMap: [Int: Int]) {
        netStream?.setAudioChannelsMap(map: channelsMap)
    }

    func setSpeechToText(enabled: Bool) {
        netStream?.setSpeechToText(enabled: enabled)
    }

    func setCameraZoomLevel(level: Float, rate: Float?) -> Float? {
        guard let device = netStream?.videoCapture()?.device else {
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
        guard let device = netStream?.videoCapture()?.device else {
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
        videoStabilizationMode: AVCaptureVideoStabilizationMode,
        videoMirrored: Bool,
        onSuccess: (() -> Void)? = nil
    ) {
        netStream?.videoCapture()?.preferredVideoStabilizationMode = videoStabilizationMode
        netStream?.videoCapture()?.isVideoMirrored = videoMirrored
        netStream?.attachCamera(device, onError: { error in
            logger.error("stream: Attach camera error: \(error)")
        }, onSuccess: {
            DispatchQueue.main.async {
                onSuccess?()
            }
        })
    }

    func attachReplaceCamera(device: AVCaptureDevice?, cameraId: UUID) {
        netStream?.attachCamera(device, replaceVideoCameraId: cameraId)
    }

    func attachReplaceAudio(cameraId: UUID?) {
        netStream?.attachAudio(nil, replaceAudioId: cameraId)
    }

    func addReplaceSampleBuffer(cameraId: UUID, sampleBuffer: CMSampleBuffer) {
        netStream?.addReplaceVideoSampleBuffer(id: cameraId, sampleBuffer)
    }

    func addReplaceAudioSampleBuffer(cameraId: UUID, sampleBuffer: CMSampleBuffer) {
        netStream?.addAudioSampleBuffer(id: cameraId, sampleBuffer)
    }

    func addReplaceCamera(cameraId: UUID, name: String) {
        netStream?.addReplaceVideo(cameraId: cameraId, name: name)
    }

    func addReplaceAudio(cameraId: UUID, name: String) {
        netStream?.addReplaceAudio(cameraId: cameraId, name: name)
    }

    func removeReplaceCamera(cameraId: UUID) {
        netStream?.removeReplaceVideo(cameraId: cameraId)
    }

    func removeReplaceAudio(cameraId: UUID) {
        netStream?.removeReplaceAudio(cameraId: cameraId)
    }

    func attachAudio(device: AVCaptureDevice?) {
        netStream?.attachAudio(device) { error in
            logger.error("stream: Attach audio error: \(error)")
        }
    }

    func getNetStream() -> NetStream? {
        return netStream
    }

    func startRecording(
        url: URL,
        videoCodec: SettingsStreamCodec,
        videoBitrate: Int?,
        keyFrameInterval: Int?,
        audioBitrate: Int?
    ) {
        var codec: AVVideoCodecType
        switch videoCodec {
        case .h264avc:
            codec = AVVideoCodecType.h264
        case .h265hevc:
            codec = AVVideoCodecType.hevc
        }
        var videoSettings: [String: Any] = [
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
            videoSettings[AVVideoCompressionPropertiesKey] = compressionProperties
        }
        var audioSettings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 0,
            AVNumberOfChannelsKey: 0,
        ]
        if let audioBitrate {
            audioSettings[AVEncoderBitRateKey] = audioBitrate
        }
        netStream?.startRecording(url: url,
                                  audioSettings: audioSettings,
                                  videoSettings: videoSettings)
    }

    func stopRecording() {
        netStream?.stopRecording()
    }

    func getFailedVideoEffect() -> String? {
        return failedVideoEffect
    }
}

extension Media: NetStreamDelegate {
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

    func streamVideo(_: NetStream, presentationTimestamp: Double) {
        DispatchQueue.main.async {
            self.videoCapturePresentationTimestamp = presentationTimestamp
        }
    }

    func streamVideo(_: NetStream, failedEffect: String?) {
        DispatchQueue.main.async {
            self.failedVideoEffect = failedEffect
        }
    }

    func streamVideo(_: NetStream, lowFpsImage: Data?, frameNumber: UInt64) {
        onLowFpsImage(lowFpsImage, frameNumber)
    }

    func streamVideo(_: NetStream, findVideoFormatError: String, activeFormat: String) {
        onFindVideoFormatError(findVideoFormatError, activeFormat)
    }

    func stream(_: NetStream, recorderFinishWriting _: AVAssetWriter) {
        logger.info("stream: Recording finished")
    }

    func streamAudio(_: NetStream, sampleBuffer: CMSampleBuffer) {
        onAudioBuffer(sampleBuffer)
    }

    func streamNoTorch() {
        onNoTorch()
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
                        if let srtla = self.srtlaClient {
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
        netStream?.videoEncodecSettings.bitRate = bitrate
    }
}

extension Media: IrlToolkitFetcherDelegate {
    func irlToolkitFetcherSuccess(url: String, reconnectTime: Double) {
        srtUrl = url
        srtlaClient?.start(uri: url, timeout: reconnectTime)
    }

    func irlToolkitFetcherError(message: String) {
        onSrtDisconnected(message)
    }
}
