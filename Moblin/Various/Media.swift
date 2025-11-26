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
    func mediaOnRtmpDestinationConnected(_ destination: String)
    func mediaOnRtmpDestinationDisconnected(_ destination: String)
    func mediaOnRistConnected()
    func mediaOnRistDisconnected()
    func mediaOnAudioMuteChange()
    func mediaOnAudioBuffer(_ sampleBuffer: CMSampleBuffer)
    func mediaOnLowFpsImage(_ lowFpsImage: Data?, _ frameNumber: UInt64)
    func mediaOnFindVideoFormatError(_ findVideoFormatError: String, _ activeFormat: String)
    func mediaOnAttachCameraError()
    func mediaOnCaptureSessionError(_ message: String)
    func mediaOnBufferedVideoReady(cameraId: UUID)
    func mediaOnBufferedVideoRemoved(cameraId: UUID)
    func mediaOnEncoderResolutionChanged(resolution: CGSize)
    func mediaOnRecorderInitSegment(data: Data)
    func mediaOnRecorderDataSegment(segment: RecorderDataSegment)
    func mediaOnRecorderFinished()
    func mediaOnNoTorch()
    func mediaOnFps(fps: Int)
    func mediaStrlaRelayDestinationAddress(address: String, port: UInt16)
    func mediaSetZoomX(x: Float)
    func mediaSetExposureBias(bias: Float)
    func mediaSelectedFps(auto: Bool)
    func mediaError(error: Error)
}

final class Media: NSObject {
    private var rtmpStreams: [RtmpStream] = []
    private var rtmpStream: RtmpStream? {
        rtmpStreams.first
    }

    private var srtStreamNew: SrtStreamNew?
    private var srtStreamOld: SrtStreamOld?
    private var ristStream: RistStream?
    private var srtlaClient: SrtlaClient?
    private var processor: Processor?
    private var srtTotalByteCount: Int64 = 0
    private var srtPreviousTotalByteCount: Int64 = 0
    private var srtSpeed: Int64 = 0
    private var currentAudioLevel: Float = defaultAudioLevel
    private var numberOfAudioChannels: Int = 0
    private var audioSampleRate: Double = 0
    private var srtUrl: String = ""
    private var latency: Int32 = 2000
    private var overheadBandwidth: Int32 = 25
    private var maximumBandwidthFollowInput: Bool = false
    weak var delegate: (any MediaDelegate)?
    private var adaptiveBitrate: AdaptiveBitrate?
    private var failedVideoEffect: String?
    var srtDroppedPacketsTotal: Int32 = 0
    private var videoEncoderSettings = VideoEncoderSettings()
    private var audioEncoderSettings = AudioEncoderSettings()
    private var multiplier: UInt32 = 0
    private var updateTickCount: UInt64 = 0
    private var belaLinesAndActions: ([String], [String])?
    private var srtConnected = false
    private var newSrt: Bool = false
    private var canvasSize: CGSize = .init(width: 1920, height: 1080)

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
        srtStopStream()
        rtmpStopStream()
        ristStopStream()
        rtmpStreams.removeAll()
        srtStreamNew = nil
        srtStreamOld = nil
        ristStream = nil
        processor = nil
    }

    func setNetStream(proto: SettingsStreamProtocol,
                      portrait: Bool,
                      timecodesEnabled: Bool,
                      builtinAudioDelay: Double,
                      destinations: [SettingsStreamMultiStreamingDestination],
                      newSrt: Bool)
    {
        self.newSrt = newSrt
        processor?.stop()
        srtStopStream()
        rtmpStopStream()
        ristStopStream()
        let processor = Processor()
        switch proto {
        case .rtmp:
            rtmpStreams = [RtmpStream(name: "Main", processor: processor, delegate: self)]
            for destination in destinations where destination.enabled {
                let rtmpStream = RtmpStream(name: destination.name, processor: processor, delegate: self)
                rtmpStream.setUrl(destination.url)
                rtmpStreams.append(rtmpStream)
            }
            srtStreamNew = nil
            srtStreamOld = nil
            ristStream = nil
        case .srt:
            if newSrt {
                srtStreamNew = SrtStreamNew(processor: processor, timecodesEnabled: timecodesEnabled, delegate: self)
                srtStreamOld = nil
            } else {
                srtStreamNew = nil
                srtStreamOld = SrtStreamOld(processor: processor, timecodesEnabled: timecodesEnabled, delegate: self)
            }
            rtmpStreams.removeAll()
            ristStream = nil
        case .rist:
            ristStream = RistStream(processor: processor, timecodesEnabled: timecodesEnabled, delegate: self)
            srtStreamNew = nil
            srtStreamOld = nil
            rtmpStreams.removeAll()
        }
        self.processor = processor
        processor.setDelegate(delegate: self)
        processor.setVideoOrientation(value: portrait ? .portrait : .landscapeRight)
        attachDefaultAudioDevice(builtinDelay: builtinAudioDelay)
    }

    func getAudioLevel() -> Float {
        return currentAudioLevel
    }

    func getNumberOfAudioChannels() -> Int {
        return numberOfAudioChannels
    }

    func getAudioSampleRate() -> Double {
        return audioSampleRate
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
            connectionPriorities: connectionPriorities,
            newSrt: newSrt
        )
        srtSetAdaptiveBitrateAlgorithm(
            targetBitrate: targetBitrate,
            adaptiveBitrateAlgorithm: adaptiveBitrateAlgorithm
        )
    }

    func srtStopStream() {
        srtStreamNew?.close()
        srtStreamOld?.close()
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

    func getNumberOfDestinations() -> Int {
        if rtmpStream != nil {
            return rtmpStreams.count
        } else {
            return 1
        }
    }

    func updateAdaptiveBitrate(overlay: Bool, relaxed: Bool) -> ([String], [String])? {
        updateTickCount += 1
        let is200MsTick = updateTickCount % 10 == 0
        if isSrtStreamActive() {
            return updateAdaptiveBitrateSrt(overlay: overlay, relaxed: relaxed, is200MsTick: is200MsTick)
        } else if is200MsTick {
            if let rtmpStream {
                return updateAdaptiveBitrateRtmp(overlay: overlay, rtmpStream: rtmpStream)
            } else if let ristStream {
                return updateAdaptiveBitrateRist(overlay: overlay, ristStream: ristStream)
            }
        }
        return nil
    }

    private func updateAdaptiveBitrateSrt(overlay: Bool, relaxed: Bool, is200MsTick: Bool) -> ([String], [String])? {
        guard srtConnected else {
            return nil
        }
        if adaptiveBitrate is AdaptiveBitrateSrtBela {
            return updateAdaptiveBitrateSrtBela(overlay: overlay, relaxed: relaxed, is200MsTick: is200MsTick)
        } else if is200MsTick {
            return updateAdaptiveBitrateSrtFight(overlay: overlay)
        } else {
            return nil
        }
    }

    private func getSrtStats() -> SrtPerformanceData? {
        return srtStreamNew?.getPerformanceData() ?? srtStreamOld?.getPerformanceData()
    }

    private func isSrtStreamActive() -> Bool {
        return srtStreamNew != nil || srtStreamOld != nil
    }

    private func updateAdaptiveBitrateSrtBela(overlay: Bool,
                                              relaxed: Bool,
                                              is200MsTick: Bool) -> ([String], [String])?
    {
        guard let stats = getSrtStats() else {
            return nil
        }
        srtDroppedPacketsTotal = stats.pktSndDropTotal
        guard let adaptiveBitrate else {
            return nil
        }
        let sndData: Int32?
        if let srtStreamOld {
            // This one blocks if srt_connect() has not returned.
            sndData = srtStreamOld.getSndData()
        } else {
            sndData = stats.pktFlightSize
        }
        guard let sndData else {
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
            if is200MsTick {
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
        guard let stats = getSrtStats() else {
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
        if let rtmpStream {
            return Int64(8 * rtmpStream.info.currentBytesPerSecond.value)
        } else if isSrtStreamActive() {
            return 8 * srtSpeed
        } else if ristStream != nil {
            return Int64(ristStream?.getSpeed() ?? 0)
        } else {
            return 0
        }
    }

    func streamTotal() -> Int64 {
        var total: Int64 = 0
        for stream in rtmpStreams {
            total += stream.info.byteCount.value
        }
        if isSrtStreamActive() {
            return srtTotalByteCount
        }
        return total
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

    private func makeStreamId(url: String) -> String? {
        return URL(string: url)?.dictionaryFromQuery()["streamid"]
    }

    func rtmpStartStream(url: String,
                         targetBitrate: UInt32,
                         adaptiveBitrate adaptiveBitrateEnabled: Bool)
    {
        if adaptiveBitrateEnabled {
            adaptiveBitrate = AdaptiveBitrateSrtFight(targetBitrate: targetBitrate, delegate: self)
        } else {
            adaptiveBitrate = nil
        }
        rtmpStream?.setUrl(url)
        for rtmpStream in rtmpStreams {
            rtmpStream.connect()
        }
    }

    func rtmpStopStream() {
        for rtmpStream in rtmpStreams {
            rtmpStream.disconnect()
        }
        adaptiveBitrate = nil
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

    func setTorch(on: Bool) {
        processor?.setTorch(value: on)
    }

    func setMute(on: Bool) {
        processor?.setHasAudio(value: !on)
    }

    func registerEffect(_ effect: VideoEffect) {
        processor?.registerVideoEffect(effect)
    }

    func registerEffectBack(_ effect: VideoEffect) {
        processor?.registerVideoEffectBack(effect)
    }

    func unregisterEffect(_ effect: VideoEffect) {
        processor?.unregisterVideoEffect(effect)
    }

    func setPendingAfterAttachEffects(effects: [VideoEffect], rotation: Double) {
        processor?.setPendingAfterAttachEffects(effects: effects, rotation: rotation)
    }

    func usePendingAfterAttachEffects() {
        processor?.usePendingAfterAttachEffects()
    }

    func setScreenPreview(enabled: Bool) {
        processor?.setScreenPreview(enabled: enabled)
    }

    func setLowFpsImage(fps: Float) {
        processor?.setLowFpsImage(fps: fps)
    }

    func setSceneSwitchTransition(sceneSwitchTransition: SceneSwitchTransition) {
        processor?.setSceneSwitchTransition(sceneSwitchTransition: sceneSwitchTransition)
    }

    func setCameraControls(enabled: Bool) {
        processor?.setCameraControls(enabled: enabled)
    }

    func takeSnapshot(age: Float, onComplete: @escaping (UIImage, CIImage, CIImage) -> Void) {
        processor?.takeSnapshot(age: age, onComplete: onComplete)
    }

    func setCleanRecordings(enabled: Bool) {
        processor?.setCleanRecordings(enabled: enabled)
    }

    func setCleanSnapshots(enabled: Bool) {
        processor?.setCleanSnapshots(enabled: enabled)
    }

    func setCleanExternalDisplay(enabled: Bool) {
        processor?.setCleanExternalDisplay(enabled: enabled)
    }

    func setVideoSize(capture: CGSize, canvas: CGSize, stream: CMVideoDimensions) {
        processor?.setVideoSize(capture: capture, canvas: canvas)
        videoEncoderSettings.videoSize = stream
        commitVideoEncoderSettings()
        canvasSize = canvas
    }

    func getCanvasSize() -> CGSize {
        return canvasSize
    }

    func setFps(fps: Int, preferAutoFps: Bool) {
        processor?.setFps(value: Double(fps), preferAutoFps: preferAutoFps)
    }

    func setColorSpace(colorSpace: AVCaptureColorSpace, onComplete: @escaping () -> Void) {
        processor?.setColorSpace(colorSpace: colorSpace, onComplete: onComplete)
    }

    private func commitVideoEncoderSettings() {
        processor?.setVideoEncoderSettings(settings: videoEncoderSettings)
    }

    private func commitAudioEncoderSettings() {
        processor?.setAudioEncoderSettings(settings: audioEncoderSettings)
    }

    func updateVideoStreamBitrate(bitrate: UInt32) {
        multiplier ^= 1
        let bitRate = getVideoStreamBitrate(bitrate: bitrate)
        videoEncoderSettings.bitRate = bitRate + multiplier * (bitRate / 10)
        commitVideoEncoderSettings()
    }

    func getVideoStreamBitrate(bitrate: UInt32) -> UInt32 {
        if let adaptiveBitrate {
            return adaptiveBitrate.getCurrentBitrate()
        } else {
            return bitrate
        }
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
        audioEncoderSettings.bitrate = bitrate
        commitAudioEncoderSettings()
    }

    func setAudioStreamFormat(format: AudioEncoderSettings.Format) {
        audioEncoderSettings.format = format
        commitAudioEncoderSettings()
    }

    func setAudioChannelsMap(channelsMap: [Int: Int]) {
        audioEncoderSettings.channelsMap = channelsMap
        commitAudioEncoderSettings()
        processor?.setAudioChannelsMap(map: channelsMap)
    }

    func setSpeechToText(enabled: Bool) {
        processor?.setSpeechToText(enabled: enabled)
    }

    func setVideoOrientation(value: AVCaptureVideoOrientation) {
        processor?.setVideoOrientation(value: value)
    }

    func setCameraZoomLevel(device: AVCaptureDevice?, level: Float, rate: Float?) -> Float? {
        guard let device else {
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

    func stopCameraZoomLevel(device: AVCaptureDevice?) -> Float? {
        guard let device else {
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

    func attachCamera(params: VideoUnitAttachParams, onSuccess: (() -> Void)? = nil) {
        processor?.attachCamera(
            params: params,
            onError: {
                self.delegate?.mediaError(error: $0)
            },
            onSuccess: {
                DispatchQueue.main.async {
                    onSuccess?()
                }
            }
        )
    }

    func attachBufferedCamera(
        devices: CaptureDevices,
        builtinDelay: Double,
        cameraPreviewLayer: AVCaptureVideoPreviewLayer,
        showCameraPreview: Bool,
        externalDisplayPreview: Bool,
        cameraId: UUID,
        ignoreFramesAfterAttachSeconds: Double,
        fillFrame: Bool,
        isLandscapeStreamAndPortraitUi: Bool
    ) {
        let params = VideoUnitAttachParams(devices: devices,
                                           builtinDelay: builtinDelay,
                                           cameraPreviewLayer: cameraPreviewLayer,
                                           showCameraPreview: showCameraPreview,
                                           externalDisplayPreview: externalDisplayPreview,
                                           bufferedVideo: cameraId,
                                           preferredVideoStabilizationMode: .off,
                                           isVideoMirrored: false,
                                           ignoreFramesAfterAttachSeconds: ignoreFramesAfterAttachSeconds,
                                           fillFrame: fillFrame,
                                           isLandscapeStreamAndPortraitUi: isLandscapeStreamAndPortraitUi)
        processor?.attachCamera(params: params)
    }

    func attachBufferedAudio(cameraId: UUID?) {
        let params = AudioUnitAttachParams(device: nil, builtinDelay: 0, bufferedAudio: cameraId)
        processor?.attachAudio(params: params)
    }

    func addBufferedAudio(cameraId: UUID, name: String, latency: Double) {
        processor?.addBufferedAudio(cameraId: cameraId, name: name, latency: latency)
    }

    func removeBufferedAudio(cameraId: UUID) {
        processor?.removeBufferedAudio(cameraId: cameraId)
    }

    func appendBufferedAudioSampleBuffer(cameraId: UUID, sampleBuffer: CMSampleBuffer) {
        processor?.appendBufferedAudioSampleBuffer(cameraId: cameraId, sampleBuffer)
    }

    func setBufferedAudioTargetLatency(cameraId: UUID, latency: Double) {
        processor?.setBufferedAudioTargetLatency(cameraId: cameraId, latency)
    }

    func addBufferedVideo(cameraId: UUID, name: String, latency: Double) {
        processor?.addBufferedVideo(cameraId: cameraId, name: name, latency: latency)
    }

    func removeBufferedVideo(cameraId: UUID) {
        processor?.removeBufferedVideo(cameraId: cameraId)
    }

    func appendBufferedVideoSampleBuffer(cameraId: UUID, sampleBuffer: CMSampleBuffer) {
        processor?.appendBufferedVideoSampleBuffer(cameraId: cameraId, sampleBuffer)
    }

    func setBufferedVideoTargetLatency(cameraId: UUID, latency: Double) {
        processor?.setBufferedVideoTargetLatency(cameraId: cameraId, latency)
    }

    func attachDefaultAudioDevice(builtinDelay: Double) {
        let params = AudioUnitAttachParams(
            device: AVCaptureDevice.default(for: .audio),
            builtinDelay: builtinDelay,
            bufferedAudio: nil
        )
        processor?.attachAudio(params: params) {
            self.delegate?.mediaError(error: $0)
        }
    }

    func getProcessor() -> Processor? {
        return processor
    }

    func startRecording(
        url: URL?, replay: Bool,
        videoCodec: SettingsStreamCodec,
        videoBitrate: Int?,
        keyFrameInterval: Int?,
        audioBitrate: Int?
    ) {
        processor?.startRecording(url: url,
                                  replay: replay,
                                  audioSettings: makeAudioCompressionSettings(audioBitrate: audioBitrate),
                                  videoSettings: makeVideoCompressionSettings(
                                      videoCodec: videoCodec,
                                      videoBitrate: videoBitrate,
                                      keyFrameInterval: keyFrameInterval
                                  ))
    }

    func setRecordUrl(url: URL?) {
        processor?.setUrl(url: url)
    }

    func setReplayBuffering(enabled: Bool) {
        processor?.setReplayBuffering(enabled: enabled)
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
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 0,
        ]
        if let audioBitrate {
            settings[AVEncoderBitRateKey] = audioBitrate
        }
        return settings
    }

    func stopRecording() {
        processor?.stopRecording()
    }

    func getFailedVideoEffect() -> String? {
        return failedVideoEffect
    }
}

extension Media: ProcessorDelegate {
    func stream(audioLevel: Float, numberOfAudioChannels: Int, sampleRate: Double) {
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
            self.audioSampleRate = sampleRate
        }
    }

    func streamVideo(failedEffect: String?) {
        DispatchQueue.main.async {
            self.failedVideoEffect = failedEffect
        }
    }

    func streamVideo(lowFpsImage: Data?, frameNumber: UInt64) {
        delegate?.mediaOnLowFpsImage(lowFpsImage, frameNumber)
    }

    func streamVideo(findVideoFormatError: String, activeFormat: String) {
        delegate?.mediaOnFindVideoFormatError(findVideoFormatError, activeFormat)
    }

    func streamVideoAttachCameraError() {
        delegate?.mediaOnAttachCameraError()
    }

    func streamVideoCaptureSessionError(_ message: String) {
        delegate?.mediaOnCaptureSessionError(message)
    }

    func streamVideoBufferedVideoReady(cameraId: UUID) {
        delegate?.mediaOnBufferedVideoReady(cameraId: cameraId)
    }

    func streamVideoBufferedVideoRemoved(cameraId: UUID) {
        delegate?.mediaOnBufferedVideoRemoved(cameraId: cameraId)
    }

    func streamVideoEncoderResolution(resolution: CGSize) {
        delegate?.mediaOnEncoderResolutionChanged(resolution: resolution)
    }

    func streamAudio(sampleBuffer: CMSampleBuffer) {
        delegate?.mediaOnAudioBuffer(sampleBuffer)
    }

    func streamRecorderInitSegment(data: Data) {
        delegate?.mediaOnRecorderInitSegment(data: data)
    }

    func streamRecorderDataSegment(segment: RecorderDataSegment) {
        delegate?.mediaOnRecorderDataSegment(segment: segment)
    }

    func streamRecorderFinished() {
        delegate?.mediaOnRecorderFinished()
    }

    func streamNoTorch() {
        delegate?.mediaOnNoTorch()
    }

    func streamVideoFps(fps: Int) {
        delegate?.mediaOnFps(fps: fps)
    }

    func streamSetZoomX(x: Float) {
        delegate?.mediaSetZoomX(x: x)
    }

    func streamSetExposureBias(bias: Float) {
        delegate?.mediaSetExposureBias(bias: bias)
    }

    func streamSelectedFps(auto: Bool) {
        delegate?.mediaSelectedFps(auto: auto)
    }
}

extension Media: SrtlaDelegate {
    func srtlaReady(port: UInt16) {
        processorControlQueue.async {
            if self.srtStreamOld != nil {
                do {
                    try self.srtStreamOld?.open(self.makeLocalhostSrtUrl(
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
            } else {
                self.srtStreamNew?.open(streamId: self.makeStreamId(url: self.srtUrl),
                                        latency: UInt16(self.latency))
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

    func srtlaReceivedPacket(packet: Data) {
        srtStreamNew?.inputPacket(packet: packet)
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

extension Media: SrtStreamNewDelegate {
    func srtStreamConnected() {
        DispatchQueue.main.async {
            self.srtConnected = true
            self.delegate?.mediaOnSrtConnected()
        }
    }

    func srtStreamDisconnected() {
        DispatchQueue.main.async {
            self.srtConnected = false
        }
        srtlaError(message: String(localized: "SRT disconnected"))
    }

    func srtStreamOutput(packet: Data) {
        srtlaClient?.handleLocalPacket(packet: packet)
    }
}

extension Media: SrtStreamOldDelegate {
    func srtStreamError() {
        DispatchQueue.main.async {
            self.srtConnected = false
        }
        srtlaError(message: String(localized: "SRT disconnected"))
    }
}

extension Media: RtmpStreamDelegate {
    func rtmpStreamStatus(_ rtmpStream: RtmpStream, code: String) {
        DispatchQueue.main.async {
            switch RtmpConnectionCode(rawValue: code) {
            case .connectFailed, .connectClosed:
                if rtmpStream === self.rtmpStream {
                    self.delegate?.mediaOnRtmpDisconnected("\(code)")
                } else {
                    self.delegate?.mediaOnRtmpDestinationDisconnected(rtmpStream.name)
                    rtmpStream.reconnectSoon()
                }
            default:
                break
            }
        }
    }

    func rtmpStreamConnected(_ rtmpStream: RtmpStream) {
        DispatchQueue.main.async {
            if rtmpStream === self.rtmpStream {
                self.delegate?.mediaOnRtmpConnected()
            } else {
                self.delegate?.mediaOnRtmpDestinationConnected(rtmpStream.name)
            }
        }
    }
}
