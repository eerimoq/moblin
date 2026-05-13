import AVFoundation
import Foundation
import SwiftUI
import VideoToolbox

private let lowPowerBitrate: UInt32 = 2_000_000

let fffffMessage = String(localized: "😢 FFFFF 😢")
let lowBitrateMessage = String(localized: "Low bitrate")
let lowBatteryMessage = String(localized: "Low battery")

class CreateStreamWizard: ObservableObject {
    var platform: WizardPlatform = .custom
    var networkSetup: WizardNetworkSetup = .none
    var customProtocol: WizardCustomProtocol = .none
    let twitchStream = SettingsStream(name: "")
    var twitchAccessToken = ""
    var twitchLoggedIn: Bool = false
    let kickStream = SettingsStream(name: "")
    var kickAccessToken = ""
    var kickLoggedIn: Bool = false
    let youTubeStream = SettingsStream(name: "")
    @Published var presenting = false
    @Published var presentingSetup = false
    @Published var showTwitchAuth = false
    @Published var showKickAuth = false
    @Published var name = ""
    @Published var backgroundStreaming = false
    @Published var twitchChannelName = ""
    @Published var twitchChannelId = ""
    @Published var kickChannelName = ""
    var kickChannelId: String?
    var kickSlug: String?
    var kickChatroomChannelId: String?
    @Published var youTubeHandle = ""
    @Published var soopChannelName = ""
    @Published var soopStreamId = ""
    @Published var obsAddress = ""
    @Published var obsPort = ""
    @Published var obsRemoteControlEnabled = false
    @Published var obsRemoteControlUrl = ""
    @Published var obsRemoteControlPassword = ""
    @Published var obsRemoteControlSourceName = ""
    @Published var obsRemoteControlMainScene = ""
    @Published var obsRemoteControlBrbScene = ""
    @Published var directIngest = ""
    @Published var directStreamKey = ""
    @Published var belaboxUrl = ""
    @Published var customSrtUrl = ""
    @Published var customSrtStreamId = ""
    @Published var customRtmpUrl = ""
    @Published var customRtmpStreamKey = ""
    @Published var customRistUrl = ""
    @Published var customWhipUrl = ""
}

enum StreamState {
    case connecting
    case connected
    case disconnected
}

func failedToConnectMessage(_ name: String) -> String {
    String(localized: "😢 Failed to connect to \(name) 😢")
}

extension Model {
    func startStream(delayed: Bool = false) {
        logger.info("stream: Start")
        guard !streaming else {
            return
        }
        if delayed, !isLive {
            return
        }
        guard stream.url != defaultStreamUrl else {
            makeErrorToast(
                title: String(
                    localized: "Please enter your stream URL in stream settings before going live."
                ),
                subTitle: String(
                    localized: "Configure it in Settings → Streams → \(stream.name) → URL."
                )
            )
            return
        }
        if database.location.resetWhenGoingLive {
            resetLocationData()
        }
        streamLog.removeAll()
        setIsLive(value: true)
        streaming = true
        streamTotalBytes = 0
        updateScreenAutoOff()
        startNetStream()
        startFetchingYouTubeChatVideoId()
        reloadViewers()
        if stream.recording.autoStartRecording {
            startRecording()
        }
        if stream.obsAutoStartStream {
            obsStartStream()
        }
        if stream.obsAutoStartRecording {
            obsStartRecording()
        }
        streamingHistoryStream = StreamingHistoryStream(settings: stream.clone())
        streamingHistoryStream!
            .updateHighestThermalState(thermalState: ThermalState(from: statusOther.thermalState))
        streamingHistoryStream!.updateLowestBatteryLevel(level: battery.level)
    }

    func stopStream(stopObsStreamIfEnabled: Bool = true, stopObsRecordingIfEnabled: Bool = true) -> Bool {
        setIsLive(value: false)
        updateScreenAutoOff()
        realtimeIrl?.stop()
        stopFetchingYouTubeChatVideoId()
        if !streaming {
            return false
        }
        logger.info("stream: Stop")
        streamTotalBytes += UInt64(media.streamTotal())
        streaming = false
        if stream.recording.autoStopRecording {
            stopRecording()
        }
        if stopObsStreamIfEnabled, stream.obsAutoStopStream {
            obsStopStream()
        }
        if stopObsRecordingIfEnabled, stream.obsAutoStopRecording {
            obsStopRecording()
        }
        stopNetStream()
        makeStreamEndedToast()
        streamState = .disconnected
        if let streamingHistoryStream {
            if let logId = streamingHistoryStream.logId {
                logsStorage.write(id: logId, data: streamLog.joined(separator: "\n").utf8Data)
            }
            streamingHistoryStream.stopTime = Date()
            streamingHistoryStream.totalBytes = streamTotalBytes
            streamingHistory.append(stream: streamingHistoryStream)
            streamingHistory.store()
        }
        return true
    }

    func isGoLiveNotificationConfigured() -> Bool {
        guard !stream.goLiveNotificationDiscordMessage.isEmpty else {
            return false
        }
        guard !stream.goLiveNotificationDiscordWebhookUrl.isEmpty else {
            return false
        }
        return true
    }

    func sendGoLiveNotification() {
        media.takeSnapshot(age: 0.0) { image, _, _ in
            guard let imageJpeg = image.jpegData(compressionQuality: 0.9) else {
                return
            }
            if let url = URL(string: self.stream.goLiveNotificationDiscordWebhookUrl) {
                self.tryUploadGoLiveNotificationToDiscord(imageJpeg, url)
            }
        }
    }

    private func tryUploadGoLiveNotificationToDiscord(_ image: Data, _ url: URL) {
        uploadImage(url: url,
                    paramName: "snapshot",
                    fileName: "snapshot.jpg",
                    image: image,
                    message: stream.goLiveNotificationDiscordMessage)
    }

    func startNetStream() {
        streamState = .connecting
        latestLowBitrateTime = .now
        moblink.streamer?.stopTunnels()
        switch stream.getProtocol() {
        case .rtmp:
            startNetStreamRtmp()
        case .srt:
            startNetStreamSrt()
        case .rist:
            startNetStreamRist()
        case .whip:
            startNetStreamWhip()
        }
        startSecondaryWhipStreamIfEnabled()
        updateSpeed(now: .now)
        streamBecameBrokenTime = nil
    }

    private func startNetStreamRtmp() {
        let rtmp = stream.rtmp
        media.rtmpStartStream(url: stream.url,
                              targetBitrate: getBitrate(),
                              adaptiveBitrate: rtmp.adaptiveBitrateEnabled)
        updateAdaptiveBitrateRtmpIfEnabled()
    }

    private func startNetStreamSrt() {
        let srt = stream.srt
        payloadSize = srt.mpegtsPacketsPerPacket() * MpegTsPacket.size
        previousSrtDroppedPacketsTotal = 0
        media.srtStartStream(
            isSrtla: stream.isSrtla(),
            url: stream.url,
            reconnectTime: 5,
            targetBitrate: getBitrate(),
            adaptiveBitrateAlgorithm: srt.adaptiveBitrateEnabled
                ? srt.adaptiveBitrate.algorithm
                : nil,
            latency: srt.latency,
            experimental: database.debug.enhancedMoblinSrt,
            overheadBandwidth: database.debug.srtOverheadBandwidth,
            maximumBandwidthFollowInput: database.debug.maximumBandwidthFollowInput,
            mpegtsPacketsPerPacket: srt.mpegtsPacketsPerPacket(),
            networkInterfaceNames: database.networkInterfaceNames,
            connectionPriorities: srt.connectionPriorities,
            dnsLookupStrategy: srt.dnsLookupStrategy
        )
        updateAdaptiveBitrateSrt(srt: srt)
    }

    private func startNetStreamRist() {
        let rist = stream.rist
        media.ristStartStream(url: stream.url,
                              bonding: rist.bonding,
                              targetBitrate: getBitrate(),
                              adaptiveBitrate: rist.adaptiveBitrateEnabled)
        updateAdaptiveBitrateRistIfEnabled()
    }

    private func startNetStreamWhip() {
        media.whipStartStream(url: stream.url,
                              headers: stream.whip.headers,
                              videoCodec: stream.codec,
                              audioCodec: stream.audioCodec,
                              videoBitrate: Double(stream.bitrate))
    }

    private func startSecondaryWhipStreamIfEnabled() {
        guard stream.secondaryStreamEnabled, !stream.secondaryStreamUrl.isEmpty else {
            return
        }
        media.secondaryWhipStartStream(url: stream.secondaryStreamUrl)
    }

    func stopNetStream() {
        moblink.streamer?.stopTunnels()
        reconnectTimer.stop()
        media.rtmpStopStream()
        media.srtStopStream()
        media.ristStopStream()
        media.whipStopStream()
        media.secondaryWhipStopStream()
        streamStartTime = nil
        updateStreamUptime(now: .now)
        updateSpeed(now: .now)
        updateAudioLevel()
        bonding.statistics = noValue
    }

    func setCurrentStream(stream: SettingsStream) {
        self.stream = stream
        stream.enabled = true
        for ostream in database.streams where ostream.id != stream.id {
            ostream.enabled = false
        }
        currentStreamId = stream.id
        updateOrientationLock()
        updateStatusStreamText()
        reloadCameraLevel()
    }

    func setCurrentStream(streamId: UUID) -> Bool {
        guard let stream = findStream(id: streamId) else {
            return false
        }
        setCurrentStream(stream: stream)
        return true
    }

    func setCurrentStream() {
        setCurrentStream(stream: database.streams.first(where: { $0.enabled }) ?? fallbackStream)
    }

    func findStream(id: UUID) -> SettingsStream? {
        database.streams.first { stream in
            stream.id == id
        }
    }

    func reloadStream() {
        cameraPosition = nil
        stopRecorderIfNeeded(forceStop: true)
        _ = stopStream()
        setNetStream()
        setStreamResolution()
        setStreamFps()
        setColorSpace()
        setStreamCodec()
        setStreamAdaptiveResolution()
        setStreamKeyFrameInterval()
        setStreamBitrate(stream: stream)
        setStreamRateControl(stream: stream)
        setAudioStreamBitrate(stream: stream)
        setAudioStreamFormat(format: stream.audioCodec.toEncoder())
        setAudioChannelsMap(channelsMap: [
            0: database.audio.outputToInputChannelsMap.channel1,
            1: database.audio.outputToInputChannelsMap.channel2,
        ])
        setAudioGain(gainDb: database.audio.gainDb)
        startRecorderIfNeeded()
        reloadConnections()
        resetChat()
        reloadLocation()
        reloadIngests()
        updateStatusStreamText()
        updateKickChannelInfoIfNeeded()
        updatePictureInPicture()
    }

    func reloadStreamIfEnabled(stream: SettingsStream) {
        if stream.enabled {
            reloadStream()
            resetSelectedScene(changeScene: false)
            updateOrientation()
        }
    }

    private func setNetStream() {
        cameraPreviewLayer?.session = nil
        media.setNetStream(
            proto: stream.getProtocol(),
            portrait: stream.portrait,
            timecodesEnabled: isTimecodesEnabled(),
            builtinAudioDelay: database.debug.builtinAudioAndVideoDelay,
            destinations: stream.multiStreaming.destinations,
            srtImplementation: stream.srt.implementation,
            limitAdaptiveBitrateByTransportBitrate: stream.rateControl != .cbr
        )
        updateTorch()
        updateMute()
        attachStream()
        setLowFpsImage()
        setSceneSwitchTransition()
        setCleanSnapshots()
        setCleanRecordings()
        setCleanExternalDisplay()
        updateCameraControls()
    }

    private func attachStream() {
        guard let processor = media.getProcessor() else {
            processor = nil
            return
        }
        processorControlQueue.async {
            processor.setDrawable(drawable: self.streamPreviewView)
            processor.setExternalDisplayDrawable(drawable: self.externalDisplayStreamPreviewView)
            DispatchQueue.main.async {
                self.processor = processor
            }
            processor.startRunning()
        }
    }

    func setStreamResolution() {
        let resolution: SettingsStreamResolution = if stream.recording.overrideStream {
            if stream.recording.resolution > stream.resolution {
                stream.recording.resolution
            } else {
                stream.resolution
            }
        } else {
            stream.resolution
        }
        let captureSize: CGSize = switch resolution {
        case .r4032x3024:
            .init(width: 4032, height: 3024)
        case .r3840x2160:
            .init(width: 3840, height: 2160)
        case .r2560x1440:
            // Use 4K camera and downscale to 1440p.
            .init(width: 3840, height: 2160)
        case .r1920x1440:
            .init(width: 1920, height: 1440)
        case .r1920x1080:
            .init(width: 1920, height: 1080)
        case .r1664x936:
            // Use 1080p camera and downscale to 936p.
            .init(width: 1920, height: 1080)
        case .r1024x768:
            .init(width: 1024, height: 768)
        case .r1280x720:
            .init(width: 1280, height: 720)
        case .r960x540:
            .init(width: 960, height: 540)
        case .r854x480:
            // Use 540p camera and downscale to 480p.
            .init(width: 960, height: 540)
        case .r640x360:
            // Use 540p camera and downscale to 360p.
            .init(width: 960, height: 540)
        case .r426x240:
            // Use 540p camera and downscale to 240p.
            .init(width: 960, height: 540)
        }
        media.setVideoSize(capture: captureSize,
                           canvas: resolution.dimensions(portrait: stream.portrait).toSize(),
                           stream: stream.resolution.dimensions(portrait: stream.portrait))
    }

    private func setStreamCodec() {
        switch stream.codec {
        case .h264avc:
            switch stream.h264Profile {
            case .baseline:
                media.setVideoProfile(profile: kVTProfileLevel_H264_Baseline_AutoLevel)
            case .main:
                media.setVideoProfile(profile: kVTProfileLevel_H264_Main_AutoLevel)
            case .high:
                media.setVideoProfile(profile: kVTProfileLevel_H264_High_AutoLevel)
            }
        case .h265hevc:
            if database.color.space == .hlgBt2020 {
                media.setVideoProfile(profile: kVTProfileLevel_HEVC_Main10_AutoLevel)
            } else {
                media.setVideoProfile(profile: kVTProfileLevel_HEVC_Main_AutoLevel)
            }
        }
        media.setAllowFrameReordering(value: stream.bFrames)
    }

    private func setStreamAdaptiveResolution() {
        media.setStreamAdaptiveResolution(value: stream.adaptiveEncoderResolution,
                                          thresholdsFactor: stream.adaptiveEncoderResolutionThreashold)
    }

    private func setStreamKeyFrameInterval() {
        media.setStreamKeyFrameInterval(seconds: stream.maxKeyFrameInterval)
    }

    func isStreamConfigured() -> Bool {
        stream != fallbackStream
    }

    func isStreamConnected() -> Bool {
        streamState == .connected
    }

    func isStreaming() -> Bool {
        streaming
    }

    func updateStreamUptime(now: ContinuousClock.Instant) {
        if let streamStartTime, isStreamConnected() {
            let elapsed = now - streamStartTime
            streamUptime.uptime = uptimeFormatter.string(from: Double(elapsed.components.seconds))!
        } else if streamUptime.uptime != noValue {
            streamUptime.uptime = noValue
        }
    }

    private func makeYouAreLiveToast() {
        makeToast(title: String(localized: "🎉 You are LIVE at \(stream.name) 🎉"))
    }

    func makeStreamEndedToast(subTitle: String? = nil, onTapped: (() -> Void)? = nil) {
        makeToast(title: String(localized: "🤟 Stream ended 🤟"), subTitle: subTitle, onTapped: onTapped)
    }

    private func makeConnectFailureToast(subTitle: String) {
        makeErrorToast(title: failedToConnectMessage(stream.name),
                       subTitle: subTitle,
                       vibrate: true)
    }

    private func makeFffffToast(subTitle: String) {
        makeErrorToast(
            title: fffffMessage,
            font: .system(size: 64).bold(),
            subTitle: subTitle,
            vibrate: true
        )
    }

    private func onConnected() {
        makeYouAreLiveToast()
        streamStartTime = .now
        streamState = .connected
        updateStreamUptime(now: .now)
    }

    private func onDisconnected(reason: String) {
        guard streaming else {
            return
        }
        logger.info("stream: Disconnected with reason: \(reason)")
        let subTitle = String(localized: "Attempting again in 5 seconds.")
        if streamState == .connected {
            streamTotalBytes += UInt64(media.streamTotal())
            makeFffffToast(subTitle: subTitle)
        } else if streamState == .connecting {
            makeConnectFailureToast(subTitle: subTitle)
        }
        streamState = .disconnected
        stopNetStream()
        reconnectTimer.startSingleShot(timeout: 5) {
            logger.info("stream: Reconnecting")
            self.startNetStream()
        }
    }

    private func handleSrtConnected() {
        onConnected()
    }

    private func handleSrtDisconnected(reason: String) {
        onDisconnected(reason: reason)
    }

    private func handleRtmpConnected() {
        onConnected()
    }

    private func handleRtmpDisconnected(message: String) {
        onDisconnected(reason: "RTMP disconnected with message \(message)")
    }

    private func handleRtmpDestinationConnected(destination: String) {
        makeToast(title: String(localized: "🎉 You are LIVE at multi stream \(destination) 🎉"))
    }

    private func handleRtmpDestinationDisconnected(destination: String) {
        makeErrorToast(title: String(localized: "😢 Multi stream \(destination) failed 😢"),
                       subTitle: String(localized: "Attempting again in 5 seconds."))
    }

    private func handleRistConnected() {
        DispatchQueue.main.async {
            self.onConnected()
        }
    }

    private func handleRistDisconnected() {
        DispatchQueue.main.async {
            self.onDisconnected(reason: "RIST disconnected")
        }
    }

    private func handleWhipConnected() {
        DispatchQueue.main.async {
            self.onConnected()
        }
    }

    private func handleWhipDisconnected(reason: String) {
        DispatchQueue.main.async {
            self.onDisconnected(reason: reason)
        }
    }

    private func handleAudioBuffer(sampleBuffer: CMSampleBuffer) {
        DispatchQueue.main.async {
            self.speechToText?.append(sampleBuffer: sampleBuffer)
        }
    }

    func updateBondingStatistics() {
        if isStreamConnected() {
            if let connections = media.srtlaConnectionStatistics() {
                handleBondingStatistics(connections: connections)
                return
            }
            if let connections = media.ristBondingStatistics() {
                handleBondingStatistics(connections: connections)
                return
            }
        }
        if bonding.statistics != noValue {
            bonding.statistics = noValue
        }
    }

    private func handleBondingStatistics(connections: [BondingConnection]) {
        if let (message, rtts, percentages) = bonding.statisticsFormatter.format(connections) {
            bonding.statistics = message
            bonding.rtts = rtts
            bonding.pieChartPercentages = percentages
        }
    }

    func updateSpeed(now: ContinuousClock.Instant) {
        if isLive {
            let speed = Int64(media.getVideoStreamBitrate(bitrate: stream.bitrate))
            checkLowBitrate(speed: speed, now: now)
            streamingHistoryStream?.updateBitrate(bitrate: speed)
            let speedMbpsOneDecimal = String(format: "%.1f", Double(speed) / 1_000_000)
            if speedMbpsOneDecimal != bitrate.speedMbpsOneDecimal {
                bitrate.speedMbpsOneDecimal = speedMbpsOneDecimal
            }
            let speedString = formatBytesPerSecond(speed: speed)
            let total = sizeFormatter.string(fromByteCount: media.streamTotal())
            let numberOfDestinations = media.getNumberOfDestinations()
            let speedAndTotal = if numberOfDestinations == 1 {
                String(localized: "\(speedString) (\(total))")
            } else {
                String(localized: "\(speedString) x\(numberOfDestinations) (\(total))")
            }
            if speedAndTotal != bitrate.speedAndTotal {
                bitrate.speedAndTotal = speedAndTotal
            }
            let bitrateStatusIconColor: Color? = if speed < stream.bitrate / 5 {
                .red
            } else if speed < stream.bitrate / 2 {
                .orange
            } else {
                nil
            }
            if bitrateStatusIconColor != bitrate.statusIconColor {
                bitrate.statusIconColor = bitrateStatusIconColor
            }
            if isWatchLocal() {
                sendSpeedAndTotalToWatch(speedAndTotal: bitrate.speedAndTotal)
            }
        } else if bitrate.speedAndTotal != noValue {
            bitrate.speedMbpsOneDecimal = noValue
            bitrate.speedAndTotal = noValue
            if isWatchLocal() {
                sendSpeedAndTotalToWatch(speedAndTotal: bitrate.speedAndTotal)
            }
        }
    }

    private func updateCameraControls() {
        media.setCameraControls(enabled: database.cameraControlsEnabled)
    }

    func setCameraControlsEnabled() {
        cameraControlEnabled = database.cameraControlsEnabled
        media.setCameraControls(enabled: database.cameraControlsEnabled)
    }

    func updateSrtlaPriorities() {
        media.setConnectionPriorities(connectionPriorities: stream.srt.connectionPriorities.clone())
    }

    private func checkLowBitrate(speed: Int64, now: ContinuousClock.Instant) {
        guard database.lowBitrateWarning else {
            return
        }
        guard streamState == .connected else {
            return
        }
        if speed < 500_000, now > latestLowBitrateTime + .seconds(15) {
            makeWarningToast(title: lowBitrateMessage, vibrate: true)
            latestLowBitrateTime = now
        }
    }

    private func handleLowFpsImage(image: Data?, frameNumber: UInt64) {
        guard let image else {
            return
        }
        DispatchQueue.main.async { [self] in
            if frameNumber % lowFpsImageFps == 0 {
                if isWatchLocal() {
                    sendPreviewToWatch(image: image)
                }
            }
            sendPreviewToRemoteControlAssistant(preview: image)
        }
    }

    private func handleAttachCameraError() {
        makeErrorToastMain(
            title: String(localized: "Camera capture setup error"),
            subTitle: videoCaptureError()
        )
    }

    private func handleCaptureSessionError(message: String) {
        makeErrorToastMain(title: message, subTitle: videoCaptureError())
    }

    private func handleEncoderResolutionChanged(resolution: CGSize) {
        let dimension = Int(resolution.minimum())
        if dimension == 2160 {
            currentResolution = "4K"
        } else {
            currentResolution = "\(dimension)p"
        }
        updateStatusStreamText()
    }

    private func handleBufferedVideoReady(cameraId: UUID) {
        activeBufferedVideoIds.insert(cameraId)
        var isNetwork = false
        if getRtmpStream(id: cameraId) != nil {
            isNetwork = true
        } else if getSrtlaStream(id: cameraId) != nil {
            isNetwork = true
        } else if let stream = getRistStream(id: cameraId) {
            isNetwork = true
            stream.connected = true
        }
        if isNetwork {
            markMicAsConnected(id: "\(cameraId) 0")
            switchMicIfNeededAfterNetworkCameraChange()
        }
        updateDisconnectProtectionVideoSourceConnected()
        updateVideoPreviews()
    }

    private func handleBufferedVideoRemoved(cameraId: UUID) {
        activeBufferedVideoIds.remove(cameraId)
        var isNetwork = false
        if getRtmpStream(id: cameraId) != nil {
            isNetwork = true
        } else if getSrtlaStream(id: cameraId) != nil {
            isNetwork = true
        } else if let stream = getRistStream(id: cameraId) {
            isNetwork = true
            stream.connected = false
        }
        if isNetwork {
            markMicAsDisconnected(id: "\(cameraId) 0")
            switchMicIfNeededAfterNetworkCameraChange()
            if isCurrentScenesVideoSourceNetwork(cameraId: cameraId) {
                updateAutoSceneSwitcherVideoSourceDisconnected()
            }
        }
        updateDisconnectProtectionVideoSourceDisconnected()
        updateVideoPreviews()
    }

    private func handleRecorderFinished() {}

    private func handleNoTorch() {
        DispatchQueue.main.async { [self] in
            if !streamOverlay.isFrontCameraSelected {
                makeErrorToast(
                    title: String(localized: "Torch unavailable in this scene."),
                    subTitle: String(localized: "Normally only available for built-in cameras.")
                )
            }
        }
    }

    private func handleFps(fps: Int) {
        DispatchQueue.main.async { [self] in
            currentFps = fps
            updateStatusStreamText()
        }
    }

    func toggleStream() {
        if isLive {
            _ = stopStream()
        } else {
            startStream()
        }
    }

    func setIsLive(value: Bool) {
        isLive = value
        updateLiveActivity()
        updatePictureInPicture()
        if isWatchLocal() {
            sendIsLiveToWatch(isLive: isLive)
        }
        remoteControlStateChanged(state: RemoteControlAssistantStreamerState(streaming: isLive))
    }

    func setStreamFps(fps: Int? = nil) {
        media.setFps(fps: fps ?? stream.fps, preferAutoFps: stream.lowLightBoost)
    }

    func setStreamBitrate(stream: SettingsStream) {
        media.setVideoStreamBitrate(bitrate: stream.bitrate)
        updateStatusStreamText()
    }

    func setStreamRateControl(stream: SettingsStream) {
        media.setVideoStreamRateControl(rateControl: stream.rateControl)
    }

    func getBitratePresetByBitrate(bitrate: UInt32) -> SettingsBitratePreset? {
        database.bitratePresets.first(where: { $0.bitrate == bitrate })
    }

    func setBitrate(bitrate: UInt32) {
        if bitrate != stream.bitrate {
            stream.bitrate = bitrate
        }
        if stream.enabled {
            setStreamBitrate(stream: stream)
        }
        guard let preset = getBitratePresetByBitrate(bitrate: bitrate) else {
            return
        }
        remoteControlStateChanged(state: RemoteControlAssistantStreamerState(bitrate: preset.id))
    }

    private func getBitrate() -> UInt32 {
        statusTopRight.isLowPowerMode ? lowPowerBitrate : stream.bitrate
    }

    func setAudioStreamBitrate(stream: SettingsStream) {
        media.setAudioStreamBitrate(bitrate: stream.audioBitrate)
        updateStatusStreamText()
    }

    func setAudioStreamFormat(format: AudioEncoderSettings.Format) {
        media.setAudioStreamFormat(format: format)
        updateStatusStreamText()
    }

    func setAudioChannelsMap(channelsMap: [Int: Int]) {
        media.setAudioChannelsMap(channelsMap: channelsMap)
    }

    func setAudioGain(gainDb: Float) {
        media.setAudioGain(gain: pow(10, gainDb / 20.0))
    }

    func isShowingStatusStream() -> Bool {
        database.show.stream && isStreamConfigured()
    }

    func updateBitrateStatus() {
        defer {
            previousBitrateStatusColorSrtDroppedPacketsTotal = media.srtDroppedPacketsTotal
            previousBitrateStatusNumberOfFailedEncodings = numberOfFailedEncodings
        }
        let newBitrateStatusColor: Color = if media
            .srtDroppedPacketsTotal > previousBitrateStatusColorSrtDroppedPacketsTotal
        {
            .red
        } else if numberOfFailedEncodings > previousBitrateStatusNumberOfFailedEncodings {
            .red
        } else {
            .white
        }
        if newBitrateStatusColor != bitrate.statusColor {
            bitrate.statusColor = newBitrateStatusColor
        }
    }

    func updateAdaptiveBitrate() {
        guard streaming else {
            return
        }
        if let (lines, actions) = media.updateAdaptiveBitrate(
            overlay: database.debug.debugOverlay,
            relaxed: relaxedBitrate
        ) {
            latestDebugLines = lines
            latestDebugActions = actions
        }
    }

    func updateDebugOverlay() {
        if database.debug.debugOverlay {
            debugOverlay.debugLines = latestDebugLines + latestDebugActions
            if logger.debugEnabled, isLive {
                logger.debug(latestDebugLines.joined(separator: ", "))
            }
        } else if !debugOverlay.debugLines.isEmpty {
            debugOverlay.debugLines = []
        }
    }

    func setPixelFormat() {
        for (format, type) in zip(pixelFormats, pixelFormatTypes) where
            database.debug.pixelFormat == format
        {
            logger.info("Setting pixel format \(format)")
            pixelFormatType = type
        }
    }
}

extension Model: @preconcurrency MediaDelegate {
    func mediaOnSrtConnected() {
        handleSrtConnected()
    }

    func mediaOnSrtDisconnected(_ reason: String) {
        handleSrtDisconnected(reason: reason)
    }

    func mediaOnRtmpConnected() {
        handleRtmpConnected()
    }

    func mediaOnRtmpDisconnected(_ message: String) {
        handleRtmpDisconnected(message: message)
    }

    func mediaOnRtmpDestinationConnected(_ destination: String) {
        handleRtmpDestinationConnected(destination: destination)
    }

    func mediaOnRtmpDestinationDisconnected(_ destination: String) {
        handleRtmpDestinationDisconnected(destination: destination)
    }

    func mediaOnRistConnected() {
        handleRistConnected()
    }

    func mediaOnRistDisconnected() {
        handleRistDisconnected()
    }

    func mediaOnWhipConnected() {
        handleWhipConnected()
    }

    func mediaOnWhipDisconnected(_ reason: String) {
        handleWhipDisconnected(reason: reason)
    }

    func mediaOnAudioMuteChange() {
        updateAudioLevel()
    }

    func mediaOnAudioBuffer(_ sampleBuffer: CMSampleBuffer) {
        handleAudioBuffer(sampleBuffer: sampleBuffer)
    }

    func mediaOnLowFpsImage(_ lowFpsImage: Data?, _ frameNumber: UInt64) {
        handleLowFpsImage(image: lowFpsImage, frameNumber: frameNumber)
    }

    func mediaOnAttachCameraError() {
        handleAttachCameraError()
    }

    func mediaOnCaptureSessionError(_ message: String) {
        handleCaptureSessionError(message: message)
    }

    func mediaOnBufferedVideoReady(cameraId: UUID) {
        DispatchQueue.main.async {
            self.handleBufferedVideoReady(cameraId: cameraId)
        }
    }

    func mediaOnBufferedVideoRemoved(cameraId: UUID) {
        DispatchQueue.main.async {
            self.handleBufferedVideoRemoved(cameraId: cameraId)
        }
    }

    func mediaOnEncoderResolutionChanged(resolution: CGSize) {
        DispatchQueue.main.async {
            self.handleEncoderResolutionChanged(resolution: resolution)
        }
    }

    func mediaOnRecorderInitSegment(data: Data) {
        handleRecorderInitSegment(data: data)
    }

    func mediaOnRecorderDataSegment(segment: RecorderDataSegment) {
        handleRecorderDataSegment(segment: segment)
    }

    func mediaOnRecorderFinished() {
        handleRecorderFinished()
    }

    func mediaOnNoTorch() {
        handleNoTorch()
    }

    func mediaOnFps(fps: Int) {
        handleFps(fps: fps)
    }

    func mediaStrlaRelayDestinationAddress(address: String, port: UInt16) {
        moblink.streamer?.startTunnels(address: address, port: port)
    }

    func mediaSetZoomX(x: Float) {
        setZoomX(x: x)
    }

    func mediaSetExposureBias(bias: Float) {
        setExposureBias(bias: bias)
    }

    func mediaSelectedFps(auto: Bool) {
        DispatchQueue.main.async {
            self.lowLightBoost = auto
            self.updateStatusStreamText()
        }
    }

    func mediaError(error: any Error) {
        makeErrorToastMain(title: error.localizedDescription, subTitle: tryGetToastSubTitle(error: error))
    }

    func mediaOnWhipPerform(request: URLRequest,
                            queue: DispatchQueue,
                            completion: (@MainActor (Data?, URLResponse?, (any Error)?) -> Void)?)
    {
        DispatchQueue.main.async {
            switch self.stream.whip.httpTransport {
            case .standard:
                httpRequest(request: request, queue: queue, completion: completion)
            case .remoteControl:
                guard let remoteControlAssistant = self.remoteControlAssistant,
                      let url = request.url,
                      let httpMethod = request.httpMethod
                else {
                    completion?(nil, nil, "")
                    return
                }
                remoteControlAssistant.whipPerform(url: url.absoluteString,
                                                   method: httpMethod,
                                                   headers: request.allHTTPHeaderFields?.map { name, value in
                                                       SettingsHttpHeader(name: name, value: value)
                                                   } ?? [],
                                                   body: request.httpBody ?? Data(),
                                                   completion: completion)
            }
        }
    }
}

private func videoCaptureError() -> String {
    String(localized: "Try to use single or low-energy cameras.")
}
