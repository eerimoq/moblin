import AVFoundation
import Network
import SwiftUI

private func isMuted(level: Float) -> Bool {
    return level.isNaN
}

private func becameMuted(old: Float, new: Float) -> Bool {
    return !isMuted(level: old) && isMuted(level: new)
}

private func becameUnmuted(old: Float, new: Float) -> Bool {
    return isMuted(level: old) && !isMuted(level: new)
}

protocol MediaDelegate: AnyObject {
    func mediaOnSrtConnected()
    func mediaOnSrtDisconnected(_ reason: String)
    func mediaOnRtmpConnected()
    func mediaOnRtmpDisconnected(_ message: String)
    func mediaOnRistConnected()
    func mediaOnRistDisconnected()
    func mediaOnAudioMuteChange()
    func mediaOnAudioBuffer(_ sampleBuffer: CMSampleBuffer)
    func mediaOnLowFpsImage(_ lowFpsImage: Data?, _ frameNumber: UInt64)
    func mediaOnFindVideoFormatError(_ findVideoFormatError: String, _ activeFormat: String)
    func mediaOnRecorderFinished()
    func mediaOnRecorderError()
    func mediaOnNoTorch()
    func mediaStrlaRelayDestinationAddress(address: String, port: UInt16)
    func mediaSetZoomX(x: Float)
    func mediaSetExposureBias(bias: Float)
    func mediaSelectedFps(fps: Double, auto: Bool)
}

final class Media: NSObject {
    private var rtmpConnection = RtmpConnection()
    private var rtmpStream: RtmpStream?
    private var srtStream: SrtStream?
    private var ristStream: RistStream?
    private var irlStream: MirlStream?
    private var srtlaClient: SrtlaClient?
    private var netStream: NetStream?
    private var srtTotalByteCount: Int64 = 0
    private var srtPreviousTotalByteCount: Int64 = 0
    private var srtSpeed: Int64 = 0
    private var currentAudioLevel: Float = defaultAudioLevel
    private var numberOfAudioChannels: Int = 0
    private var srtUrl: String = ""
    private var latency: Int32 = 2000
    private var overheadBandwidth: Int32 = 25
    private var maximumBandwidthFollowInput: Bool = false
    weak var delegate: (any MediaDelegate)?
    private var adaptiveBitrate: AdaptiveBitrate?
    private var failedVideoEffect: String?
    var srtDroppedPacketsTotal: Int32 = 0
    private var videoEncoderSettings = VideoEncoderSettings()
    private var audioEncoderSettings = AudioCodecOutputSettings()
    private var multiplier: UInt32 = 0
    private var updateTickCount: UInt64 = 0
    private var belaLinesAndActions: ([String], [String])?
    private var srtConnected = false

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
        rtmpConnection = RtmpConnection()
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

    func setNetStream(proto: SettingsStreamProtocol, portrait: Bool, timecodesEnabled: Bool) {
        netStream?.stopMixer()
        srtStopStream()
        rtmpStopStream()
        ristStopStream()
        irlStopStream()
        rtmpConnection = RtmpConnection()
        switch proto {
        case .rtmp:
            rtmpStream = RtmpStream(connection: rtmpConnection)
            srtStream = nil
            ristStream = nil
            irlStream = nil
            netStream = rtmpStream
        case .srt:
            srtStream = SrtStream(timecodesEnabled: timecodesEnabled, delegate: self)
            rtmpStream = nil
            ristStream = nil
            irlStream = nil
            netStream = srtStream
        case .rist:
            ristStream = RistStream(deletate: self)
            srtStream = nil
            rtmpStream = nil
            irlStream = nil
            netStream = ristStream
        case .irl:
            irlStream = MirlStream()
            srtStream = nil
            rtmpStream = nil
            ristStream = nil
            netStream = irlStream
        }
        netStream!.delegate = self
        netStream!.setVideoOrientation(value: portrait ? .portrait : .landscapeRight)
        attachDefaultAudioDevice()
    }

    func getAudioLevel() -> Float {
        return currentAudioLevel
    }

    func getNumberOfAudioChannels() -> Int {
        return numberOfAudioChannels
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
        connectionPriorities: SettingsStreamSrtConnectionPriorities,
        dnsLookupStrategy: SettingsDnsLookupStrategy
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
        srtlaClient!.start(uri: url, timeout: reconnectTime + 1, dnsLookupStrategy: dnsLookupStrategy)
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
        srtConnected = false
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
        srtSetAdaptiveBitrateAlgorithm(
            targetBitrate: targetBitrate,
            adaptiveBitrateAlgorithm: adaptiveBitrateAlgorithm
        )
    }

    func srtStopStream() {
        srtStream?.close()
        srtlaClient?.stop()
        srtlaClient = nil
        adaptiveBitrate = nil
    }

    func addMoblink(endpoint: NWEndpoint, id: UUID, name: String) {
        srtlaClient?.addMoblink(endpoint: endpoint, id: id, name: name)
        ristStream?.addMoblink(endpoint: endpoint, id: id, name: name)
    }

    func removeMoblink(endpoint: NWEndpoint) {
        srtlaClient?.removeMoblink(endpoint: endpoint)
        ristStream?.removeMoblink(endpoint: endpoint)
    }

    func srtSetAdaptiveBitrateAlgorithm(
        targetBitrate: UInt32,
        adaptiveBitrateAlgorithm: SettingsStreamSrtAdaptiveBitrateAlgorithm?
    ) {
        switch adaptiveBitrateAlgorithm {
        case .fastIrl, .slowIrl, .customIrl:
            adaptiveBitrate = AdaptiveBitrateSrtFight(targetBitrate: targetBitrate, delegate: self)
        case .belabox:
            adaptiveBitrate = AdaptiveBitrateSrtBela(targetBitrate: targetBitrate, delegate: self)
        case nil:
            adaptiveBitrate = nil
        }
    }

    func setNetworkInterfaceNames(networkInterfaceNames: [SettingsNetworkInterfaceName]) {
        srtlaClient?.setNetworkInterfaceNames(networkInterfaceNames: networkInterfaceNames)
    }

    private func is200MsTick() -> Bool {
        return updateTickCount % 10 == 0
    }

    func updateAdaptiveBitrate(overlay: Bool, relaxed: Bool) -> ([String], [String])? {
        updateTickCount += 1
        if srtStream != nil {
            return updateAdaptiveBitrateSrt(overlay: overlay, relaxed: relaxed)
        } else if let rtmpStream {
            return updateAdaptiveBitrateRtmp(overlay: overlay, rtmpStream: rtmpStream)
        } else if let ristStream {
            return updateAdaptiveBitrateRist(overlay: overlay, ristStream: ristStream)
        }
        return nil
    }

    private func updateAdaptiveBitrateSrt(overlay: Bool, relaxed: Bool) -> ([String], [String])? {
        if adaptiveBitrate is AdaptiveBitrateSrtBela {
            return updateAdaptiveBitrateSrtBela(overlay: overlay, relaxed: relaxed)
        } else {
            return updateAdaptiveBitrateSrtFight(overlay: overlay)
        }
    }

    private func updateAdaptiveBitrateSrtBela(overlay: Bool, relaxed: Bool) -> ([String], [String])? {
        guard srtConnected else {
            return nil
        }
        guard let stats = srtStream?.getPerformanceData() else {
            return nil
        }
        srtDroppedPacketsTotal = stats.pktSndDropTotal
        guard let adaptiveBitrate else {
            return nil
        }
        // This one blocks if srt_connect() has not returned.
        guard let sndData = srtStream?.getSndData() else {
            return nil
        }
        adaptiveBitrate.update(stats: StreamStats(
            rttMs: stats.msRtt,
            packetsInFlight: Double(sndData),
            transportBitrate: streamSpeed(),
            latency: latency,
            mbpsSendRate: stats.mbpsSendRate,
            relaxed: relaxed
        ))
        if overlay {
            if is200MsTick() {
                belaLinesAndActions = ([
                    """
                    R: \(stats.pktRetransTotal) N: \(stats.pktRecvNakTotal) \
                    D: \(stats.pktSndDropTotal) E: \(numberOfFailedEncodings)
                    """,
                    "msRTT: \(stats.msRtt)",
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
        guard let stats = srtStream?.getPerformanceData() else {
            return nil
        }
        srtDroppedPacketsTotal = stats.pktSndDropTotal
        adaptiveBitrate?.update(stats: StreamStats(
            rttMs: stats.msRtt,
            packetsInFlight: Double(stats.pktFlightSize),
            transportBitrate: streamSpeed(),
            latency: latency,
            mbpsSendRate: stats.mbpsSendRate,
            relaxed: false
        ))
        guard overlay else {
            return nil
        }
        if let adaptiveBitrate {
            return ([
                """
                R: \(stats.pktRetransTotal) N: \(stats.pktRecvNakTotal) \
                D: \(stats.pktSndDropTotal) E: \(numberOfFailedEncodings)
                """,
                "msRTT: \(stats.msRtt)",
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
                "pktRecvNAKTotal: \(stats.pktRecvNakTotal)",
                "pktSndDropTotal: \(stats.pktSndDropTotal)",
                "msRTT: \(stats.msRtt)",
                "pktFlightSize: \(stats.pktFlightSize)",
                "pktSndBuf: \(stats.pktSndBuf)",
            ], [])
        }
    }

    private func updateAdaptiveBitrateRtmp(overlay: Bool, rtmpStream: RtmpStream) -> ([String], [String])? {
        guard is200MsTick() else {
            return nil
        }
        let stats = rtmpStream.info.stats.value
        adaptiveBitrate?.update(stats: StreamStats(
            rttMs: stats.rttMs,
            packetsInFlight: Double(stats.packetsInFlight),
            transportBitrate: streamSpeed(),
            latency: nil,
            mbpsSendRate: nil,
            relaxed: nil
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
            mbpsSendRate: nil,
            relaxed: false
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
        rtmpStream?.setStreamKey(makeRtmpStreamName(url: url))
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
        rtmpConnection.disconnect()
        adaptiveBitrate = nil
    }

    func rtmpMultiTrackStartStream(_ url: String, _ videoEncoderSettings: [VideoEncoderSettings]) {
        logger.info("stream: Multi track URL \(url)")
        for videoEncoderSetting in videoEncoderSettings {
            logger.info("stream: Multi track video encoder config \(videoEncoderSetting)")
        }
    }

    @objc
    private func rtmpStatusHandler(_ notification: Notification) {
        guard let event = RtmpEvent.from(notification),
              let data = event.data as? AsObject,
              let code = data["code"] as? String
        else {
            return
        }
        DispatchQueue.main.async {
            switch RtmpConnectionCode(rawValue: code) {
            case .connectSuccess:
                self.rtmpStream?.publish()
                self.delegate?.mediaOnRtmpConnected()
            case .connectFailed, .connectClosed:
                self.delegate?.mediaOnRtmpDisconnected("\(code)")
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

    func setPendingAfterAttachEffects(effects: [VideoEffect], rotation: Double) {
        netStream?.setPendingAfterAttachEffects(effects: effects, rotation: rotation)
    }

    func usePendingAfterAttachEffects() {
        netStream?.usePendingAfterAttachEffects()
    }

    func setLowFpsImage(fps: Float) {
        netStream?.setLowFpsImage(fps: fps)
    }

    func setSceneSwitchTransition(sceneSwitchTransition: SceneSwitchTransition) {
        netStream?.setSceneSwitchTransition(sceneSwitchTransition: sceneSwitchTransition)
    }

    func setCameraControls(enabled: Bool) {
        netStream?.setCameraControls(enabled: enabled)
    }

    func takeSnapshot(age: Float, onComplete: @escaping (UIImage, UIImage?, CIImage) -> Void) {
        netStream?.takeSnapshot(age: age, onComplete: onComplete)
    }

    func setVideoSize(capture: CGSize, output: CGSize) {
        netStream?.setVideoSize(capture: capture, output: output)
        videoEncoderSettings.videoSize = .init(
            width: Int32(output.width),
            height: Int32(output.height)
        )
        commitVideoEncoderSettings()
    }

    func getVideoSize() -> CGSize {
        let size = videoEncoderSettings.videoSize
        return CGSize(width: CGFloat(size.width), height: CGFloat(size.height))
    }

    func setStreamFps(fps: Int) {
        netStream?.setFrameRate(value: Double(fps))
    }

    func setStreamPreferAutoFps(value: Bool) {
        netStream?.setPreferFrameRate(value: value)
    }

    func setColorSpace(colorSpace: AVCaptureColorSpace, onComplete: @escaping () -> Void) {
        netStream?.setColorSpace(colorSpace: colorSpace, onComplete: onComplete)
    }

    private func commitVideoEncoderSettings() {
        netStream?.setVideoEncoderSettings(settings: videoEncoderSettings)
    }

    private func commitAudioEncoderSettings() {
        netStream?.setAudioEncoderSettings(settings: audioEncoderSettings)
    }

    func updateVideoStreamBitrate(bitrate: UInt32) {
        multiplier ^= 1
        let bitRate = getVideoStreamBitrate(bitrate: bitrate)
        videoEncoderSettings.bitRate = bitRate + multiplier * (bitRate / 10)
        commitVideoEncoderSettings()
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
        if let adaptiveBitrate {
            adaptiveBitrate.setTargetBitrate(bitrate: bitrate)
        } else {
            videoEncoderSettings.bitRate = bitrate
            commitVideoEncoderSettings()
        }
    }

    func setVideoProfile(profile: CFString) {
        videoEncoderSettings.profileLevel = profile as String
        commitVideoEncoderSettings()
    }

    func setAllowFrameReordering(value: Bool) {
        videoEncoderSettings.allowFrameReordering = value
        commitVideoEncoderSettings()
    }

    func setStreamKeyFrameInterval(seconds: Int32) {
        videoEncoderSettings.maxKeyFrameIntervalDuration = seconds
        commitVideoEncoderSettings()
    }

    func setStreamAdaptiveResolution(value: Bool) {
        videoEncoderSettings.adaptiveResolution = value
        commitVideoEncoderSettings()
    }

    func setAudioStreamBitrate(bitrate: Int) {
        audioEncoderSettings.bitRate = bitrate
        commitAudioEncoderSettings()
    }

    func setAudioStreamFormat(format: AudioCodecOutputSettings.Format) {
        audioEncoderSettings.format = format
        commitAudioEncoderSettings()
    }

    func setAudioChannelsMap(channelsMap: [Int: Int]) {
        audioEncoderSettings.channelsMap = channelsMap
        commitAudioEncoderSettings()
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
        cameraPreviewLayer: AVCaptureVideoPreviewLayer?,
        showCameraPreview: Bool,
        videoStabilizationMode: AVCaptureVideoStabilizationMode,
        videoMirrored: Bool,
        ignoreFramesAfterAttachSeconds: Double,
        onSuccess: (() -> Void)? = nil
    ) {
        netStream?.attachCamera(
            device,
            cameraPreviewLayer,
            showCameraPreview,
            videoStabilizationMode,
            videoMirrored,
            ignoreFramesAfterAttachSeconds,
            onError: { error in
                logger.error("stream: Attach camera error: \(error)")
            },
            onSuccess: {
                DispatchQueue.main.async {
                    onSuccess?()
                }
            }
        )
    }

    func attachReplaceCamera(
        device: AVCaptureDevice?,
        cameraPreviewLayer: AVCaptureVideoPreviewLayer?,
        cameraId: UUID,
        ignoreFramesAfterAttachSeconds: Double
    ) {
        netStream?.attachCamera(
            device,
            cameraPreviewLayer,
            false,
            .off,
            false,
            ignoreFramesAfterAttachSeconds,
            replaceVideoCameraId: cameraId
        )
    }

    func attachReplaceAudio(cameraId: UUID?) {
        netStream?.attachAudio(nil, replaceAudioId: cameraId)
    }

    func addReplaceAudio(cameraId: UUID, name: String, latency: Double) {
        netStream?.addReplaceAudio(cameraId: cameraId, name: name, latency: latency)
    }

    func removeReplaceAudio(cameraId: UUID) {
        netStream?.removeReplaceAudio(cameraId: cameraId)
    }

    func addReplaceAudioSampleBuffer(cameraId: UUID, sampleBuffer: CMSampleBuffer) {
        netStream?.addReplaceAudioSampleBuffer(cameraId: cameraId, sampleBuffer)
    }

    func setReplaceAudioTargetLatency(cameraId: UUID, latency: Double) {
        netStream?.setReplaceAudioTargetLatency(cameraId: cameraId, latency)
    }

    func addReplaceVideo(cameraId: UUID, name: String, latency: Double) {
        netStream?.addReplaceVideo(cameraId: cameraId, name: name, latency: latency)
    }

    func removeReplaceVideo(cameraId: UUID) {
        netStream?.removeReplaceVideo(cameraId: cameraId)
    }

    func addReplaceVideoSampleBuffer(cameraId: UUID, sampleBuffer: CMSampleBuffer) {
        netStream?.addReplaceVideoSampleBuffer(cameraId: cameraId, sampleBuffer)
    }

    func setReplaceVideoTargetLatency(cameraId: UUID, latency: Double) {
        netStream?.setReplaceVideoTargetLatency(cameraId: cameraId, latency)
    }

    func attachDefaultAudioDevice() {
        netStream?.attachAudio(AVCaptureDevice.default(for: .audio)) { error in
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
        netStream?.startRecording(url: url,
                                  audioSettings: makeAudioCompressionSettings(audioBitrate: audioBitrate),
                                  videoSettings: makeVideoCompressionSettings(
                                      videoCodec: videoCodec,
                                      videoBitrate: videoBitrate,
                                      keyFrameInterval: keyFrameInterval
                                  ))
    }

    private func makeVideoCompressionSettings(videoCodec: SettingsStreamCodec,
                                              videoBitrate: Int?,
                                              keyFrameInterval: Int?) -> [String: Any]
    {
        var codec: AVVideoCodecType
        switch videoCodec {
        case .h264avc:
            codec = AVVideoCodecType.h264
        case .h265hevc:
            codec = AVVideoCodecType.hevc
        }
        var settings: [String: Any] = [
            AVVideoCodecKey: codec,
            AVVideoWidthKey: 0,
            AVVideoHeightKey: 0,
        ]
        var compressionProperties: [String: Any] = [:]
        if let videoBitrate {
            compressionProperties[AVVideoAverageBitRateKey] = videoBitrate
        }
        if let keyFrameInterval {
            compressionProperties[AVVideoMaxKeyFrameIntervalDurationKey] = keyFrameInterval
        }
        if !compressionProperties.isEmpty {
            settings[AVVideoCompressionPropertiesKey] = compressionProperties
        }
        return settings
    }

    private func makeAudioCompressionSettings(audioBitrate: Int?) -> [String: Any] {
        var settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 0,
            AVNumberOfChannelsKey: 0,
        ]
        if let audioBitrate {
            settings[AVEncoderBitRateKey] = audioBitrate
        }
        return settings
    }

    func stopRecording() {
        netStream?.stopRecording()
    }

    func getFailedVideoEffect() -> String? {
        return failedVideoEffect
    }
}

extension Media: NetStreamDelegate {
    func stream(_: NetStream, audioLevel: Float, numberOfAudioChannels: Int) {
        DispatchQueue.main.async {
            if becameMuted(old: self.currentAudioLevel, new: audioLevel) || becameUnmuted(
                old: self.currentAudioLevel,
                new: audioLevel
            ) {
                self.currentAudioLevel = audioLevel
                self.delegate?.mediaOnAudioMuteChange()
            } else {
                self.currentAudioLevel = audioLevel
            }
            self.numberOfAudioChannels = numberOfAudioChannels
        }
    }

    func streamVideo(_: NetStream, presentationTimestamp _: Double) {}

    func streamVideo(_: NetStream, failedEffect: String?) {
        DispatchQueue.main.async {
            self.failedVideoEffect = failedEffect
        }
    }

    func streamVideo(_: NetStream, lowFpsImage: Data?, frameNumber: UInt64) {
        delegate?.mediaOnLowFpsImage(lowFpsImage, frameNumber)
    }

    func streamVideo(_: NetStream, findVideoFormatError: String, activeFormat: String) {
        delegate?.mediaOnFindVideoFormatError(findVideoFormatError, activeFormat)
    }

    func streamAudio(_: NetStream, sampleBuffer: CMSampleBuffer) {
        delegate?.mediaOnAudioBuffer(sampleBuffer)
    }

    func streamRecorderFinished() {
        delegate?.mediaOnRecorderFinished()
    }

    func streamRecorderError() {
        delegate?.mediaOnRecorderError()
    }

    func streamNoTorch() {
        delegate?.mediaOnNoTorch()
    }

    func streamSetZoomX(x: Float) {
        delegate?.mediaSetZoomX(x: x)
    }

    func streamSetExposureBias(bias: Float) {
        delegate?.mediaSetExposureBias(bias: bias)
    }

    func streamSelectedFps(fps: Double, auto: Bool) {
        delegate?.mediaSelectedFps(fps: fps, auto: auto)
    }
}

extension Media: SrtlaDelegate {
    func srtlaReady(port: UInt16) {
        netStreamLockQueue.async {
            do {
                try self.srtStream?.open(self.makeLocalhostSrtUrl(
                    url: self.srtUrl,
                    port: port,
                    latency: self.latency,
                    overheadBandwidth: self.overheadBandwidth,
                    maximumBandwidthFollowInput: self.maximumBandwidthFollowInput
                )) { [weak self] data in
                    guard let self else {
                        return false
                    }
                    if let srtla = self.srtlaClient {
                        srtlaClientQueue.async {
                            srtla.handleLocalPacket(packet: data)
                        }
                    }
                    return true
                }
                DispatchQueue.main.async {
                    self.srtConnected = true
                    self.delegate?.mediaOnSrtConnected()
                }
            } catch {
                DispatchQueue.main.async {
                    self.delegate?.mediaOnSrtDisconnected(
                        String(localized: "SRT connect failed with \(error.localizedDescription)")
                    )
                }
            }
        }
    }

    func srtlaError(message: String) {
        DispatchQueue.main.async {
            logger.info("stream: SRT error: \(message)")
            self.delegate?.mediaOnSrtDisconnected(String(localized: "SRT error: \(message)"))
        }
    }

    func moblinkStreamerDestinationAddress(address: String, port: UInt16) {
        DispatchQueue.main.async {
            self.delegate?.mediaStrlaRelayDestinationAddress(address: address, port: port)
        }
    }
}

extension Media: AdaptiveBitrateDelegate {
    func adaptiveBitrateSetVideoStreamBitrate(bitrate: UInt32) {
        videoEncoderSettings.bitRate = bitrate
        commitVideoEncoderSettings()
    }
}

extension Media: RistStreamDelegate {
    func ristStreamOnConnected() {
        delegate?.mediaOnRistConnected()
    }

    func ristStreamOnDisconnected() {
        delegate?.mediaOnRistDisconnected()
    }

    func ristStreamRelayDestinationAddress(address: String, port: UInt16) {
        DispatchQueue.main.async {
            self.delegate?.mediaStrlaRelayDestinationAddress(address: address, port: port)
        }
    }
}

extension Media: SrtStreamDelegate {
    func srtStreamError() {
        DispatchQueue.main.async {
            self.srtConnected = false
        }
        srtlaError(message: String(localized: "SRT disconnected"))
    }
}
