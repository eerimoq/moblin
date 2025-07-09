import AVFoundation
import Foundation
import SwiftUI
import VideoToolbox

private let iAmLiveWebhookUrl =
    URL(
        string: """
        https://discord.com/api/webhooks/1383532422573985822/\
        jI3eX5CLADDvhWa93guXttqHCZ_uOalfsYQi2AeYcu6IhFSFw1StNIWPTKTIuFzrWn-q
        """
    )!
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
    @Published var isPresenting = false
    @Published var isPresentingSetup = false
    @Published var showTwitchAuth = false
    @Published var name = ""
    @Published var twitchChannelName = ""
    @Published var twitchChannelId = ""
    @Published var kickChannelName = ""
    @Published var youTubeHandle = ""
    @Published var afreecaTvChannelName = ""
    @Published var afreecaTvStreamId = ""
    @Published var obsAddress = ""
    @Published var obsPort = ""
    @Published var obsRemoteControlEnabled = false
    @Published var obsRemoteControlUrl = ""
    @Published var obsRemoteControlPassword = ""
    @Published var obsRemoteControlSourceName = ""
    @Published var obsRemoteControlBrbScene = ""
    @Published var directIngest = ""
    @Published var directStreamKey = ""
    @Published var chatBttv = false
    @Published var chatFfz = false
    @Published var chatSeventv = false
    @Published var belaboxUrl = ""
    @Published var customSrtUrl = ""
    @Published var customSrtStreamId = ""
    @Published var customRtmpUrl = ""
    @Published var customRtmpStreamKey = ""
    @Published var customRistUrl = ""
}

enum StreamState {
    case connecting
    case connected
    case disconnected
}

func failedToConnectMessage(_ name: String) -> String {
    return String(localized: "😢 Failed to connect to \(name) 😢")
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
        streamTotalChatMessages = 0
        updateScreenAutoOff()
        startNetStream()
        startFetchingYouTubeChatVideoId()
        if stream.recording.autoStartRecording! {
            startRecording()
        }
        if stream.obsAutoStartStream {
            obsStartStream()
        }
        if stream.obsAutoStartRecording {
            obsStartRecording()
        }
        streamingHistoryStream = StreamingHistoryStream(settings: stream.clone())
        streamingHistoryStream!.updateHighestThermalState(thermalState: ThermalState(from: statusOther.thermalState))
        streamingHistoryStream!.updateLowestBatteryLevel(level: battery.level)
    }

    func stopStream(stopObsStreamIfEnabled: Bool = true, stopObsRecordingIfEnabled: Bool = true) {
        setIsLive(value: false)
        updateScreenAutoOff()
        realtimeIrl?.stop()
        stopFetchingYouTubeChatVideoId()
        if !streaming {
            return
        }
        logger.info("stream: Stop")
        streamTotalBytes += UInt64(media.streamTotal())
        streaming = false
        if stream.recording.autoStopRecording! {
            stopRecording()
        }
        if stopObsStreamIfEnabled, stream.obsAutoStopStream {
            obsStopStream()
        }
        if stopObsRecordingIfEnabled, stream.obsAutoStopRecording {
            obsStopRecording()
        }
        stopNetStream()
        streamState = .disconnected
        if let streamingHistoryStream {
            if let logId = streamingHistoryStream.logId {
                logsStorage.write(id: logId, data: streamLog.joined(separator: "\n").utf8Data)
            }
            streamingHistoryStream.stopTime = Date()
            streamingHistoryStream.totalBytes = streamTotalBytes
            streamingHistoryStream.numberOfChatMessages = streamTotalChatMessages
            streamingHistory.append(stream: streamingHistoryStream)
            streamingHistory.store()
        }
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
        media.takeSnapshot(age: 0.0) { image, _ in
            guard let imageJpeg = image.jpegData(compressionQuality: 0.9) else {
                return
            }
            DispatchQueue.main.async {
                if let url = URL(string: self.stream.goLiveNotificationDiscordWebhookUrl) {
                    self.tryUploadGoLiveNotificationToDiscord(imageJpeg, url)
                }
            }
        }
    }

    private func tryUploadGoLiveNotificationToDiscord(_ image: Data, _ url: URL) {
        uploadImage(
            url: url,
            paramName: "snapshot",
            fileName: "snapshot.jpg",
            image: image,
            message: stream.goLiveNotificationDiscordMessage
        ) { _ in }
    }

    private func startNetStream() {
        streamState = .connecting
        latestLowBitrateTime = .now
        moblink.streamer?.stopTunnels()
        if stream.twitchMultiTrackEnabled {
            startNetStreamMultiTrack()
        } else {
            startNetStreamSingleTrack()
        }
    }

    private func startNetStreamMultiTrack() {
        twitchMultiTrackGetClientConfiguration(
            url: stream.url,
            dimensions: stream.dimensions(),
            fps: stream.fps
        ) { response in
            DispatchQueue.main.async {
                self.startNetStreamMultiTrackCompletion(response: response)
            }
        }
    }

    private func startNetStreamMultiTrackCompletion(response: TwitchMultiTrackGetClientConfigurationResponse?) {
        guard let response else {
            return
        }
        guard let ingestEndpoint = response.ingest_endpoints.first(where: { $0.proto == "RTMP" }) else {
            return
        }
        let url = ingestEndpoint.url_template.replacingOccurrences(
            of: "{stream_key}",
            with: ingestEndpoint.authentication
        )
        guard let videoEncoderSettings = createMultiTrackVideoCodecSettings(encoderConfigurations: response
            .encoder_configurations)
        else {
            return
        }
        media.rtmpMultiTrackStartStream(url, videoEncoderSettings)
        updateSpeed(now: .now)
    }

    private func createMultiTrackVideoCodecSettings(
        encoderConfigurations: [TwitchMultiTrackGetClientConfigurationEncoderContiguration]
    )
        -> [VideoEncoderSettings]?
    {
        var videoEncoderSettings: [VideoEncoderSettings] = []
        for encoderConfiguration in encoderConfigurations {
            var settings = VideoEncoderSettings()
            let bitrate = encoderConfiguration.settings.bitrate
            guard bitrate >= 100, bitrate <= 50000 else {
                return nil
            }
            settings.bitRate = bitrate * 1000
            let width = encoderConfiguration.width
            let height = encoderConfiguration.height
            guard width >= 1, width <= 5000 else {
                return nil
            }
            guard height >= 1, height <= 5000 else {
                return nil
            }
            settings.videoSize = CMVideoDimensions(width: width, height: height)
            settings.maxKeyFrameIntervalDuration = encoderConfiguration.settings.keyint_sec
            settings.allowFrameReordering = encoderConfiguration.settings.bframes
            let codec = encoderConfiguration.type
            let profile = encoderConfiguration.settings.profile
            if codec.hasSuffix("avc"), profile == "main" {
                settings.profileLevel = kVTProfileLevel_H264_Main_AutoLevel as String
            } else if codec.hasSuffix("avc"), profile == "high" {
                settings.profileLevel = kVTProfileLevel_H264_High_AutoLevel as String
            } else if codec.hasSuffix("hevc"), profile == "main" {
                settings.profileLevel = kVTProfileLevel_HEVC_Main_AutoLevel as String
            } else {
                logger.error("Unsupported multi track codec and profile combination: \(codec) \(profile)")
                return nil
            }
            videoEncoderSettings.append(settings)
        }
        return videoEncoderSettings
    }

    private func startNetStreamSingleTrack() {
        switch stream.getProtocol() {
        case .rtmp:
            media.rtmpStartStream(url: stream.url,
                                  targetBitrate: stream.bitrate,
                                  adaptiveBitrate: stream.rtmp.adaptiveBitrateEnabled)
            updateAdaptiveBitrateRtmpIfEnabled()
        case .srt:
            payloadSize = stream.srt.mpegtsPacketsPerPacket * MpegTsPacket.size
            media.srtStartStream(
                isSrtla: stream.isSrtla(),
                url: stream.url,
                reconnectTime: 5,
                targetBitrate: stream.bitrate,
                adaptiveBitrateAlgorithm: stream.srt.adaptiveBitrateEnabled! ? stream.srt.adaptiveBitrate!
                    .algorithm : nil,
                latency: stream.srt.latency,
                overheadBandwidth: database.debug.srtOverheadBandwidth,
                maximumBandwidthFollowInput: database.debug.maximumBandwidthFollowInput,
                mpegtsPacketsPerPacket: stream.srt.mpegtsPacketsPerPacket,
                networkInterfaceNames: database.networkInterfaceNames,
                connectionPriorities: stream.srt.connectionPriorities!,
                dnsLookupStrategy: stream.srt.dnsLookupStrategy!
            )
            updateAdaptiveBitrateSrt(stream: stream)
        case .rist:
            media.ristStartStream(url: stream.url,
                                  bonding: stream.rist.bonding,
                                  targetBitrate: stream.bitrate,
                                  adaptiveBitrate: stream.rist.adaptiveBitrateEnabled)
            updateAdaptiveBitrateRistIfEnabled()
        case .irl:
            media.irlStartStream()
        }
        updateSpeed(now: .now)
    }

    private func stopNetStream(reconnect: Bool = false) {
        moblink.streamer?.stopTunnels()
        reconnectTimer?.invalidate()
        media.rtmpStopStream()
        media.srtStopStream()
        media.ristStopStream()
        streamStartTime = nil
        updateStreamUptime(now: .now)
        updateSpeed(now: .now)
        updateAudioLevel()
        bonding.statistics = noValue
        if !reconnect {
            makeStreamEndedToast()
        }
    }

    func setCurrentStream(stream: SettingsStream) {
        stream.enabled = true
        for ostream in database.streams where ostream.id != stream.id {
            ostream.enabled = false
        }
        currentStreamId = stream.id
        updateOrientationLock()
        updateStatusStreamText()
    }

    func setCurrentStream(streamId: UUID) -> Bool {
        guard let stream = findStream(id: streamId) else {
            return false
        }
        setCurrentStream(stream: stream)
        return true
    }

    func findStream(id: UUID) -> SettingsStream? {
        return database.streams.first { stream in
            stream.id == id
        }
    }

    func reloadStream() {
        cameraPosition = nil
        stopRecorderIfNeeded(forceStop: true)
        stopStream()
        setNetStream()
        setStreamResolution()
        setStreamFps()
        setStreamPreferAutoFps()
        setColorSpace()
        setStreamCodec()
        setStreamAdaptiveResolution()
        setStreamKeyFrameInterval()
        setStreamBitrate(stream: stream)
        setAudioStreamBitrate(stream: stream)
        setAudioStreamFormat(format: .aac)
        setAudioChannelsMap(channelsMap: [
            0: database.audio.audioOutputToInputChannelsMap!.channel1,
            1: database.audio.audioOutputToInputChannelsMap!.channel2,
        ])
        startRecorderIfNeeded()
        reloadConnections()
        resetChat()
        reloadLocation()
        reloadRtmpStreams()
        updateStatusStreamText()
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
            builtinAudioDelay: database.debug.builtinAudioAndVideoDelay
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
        guard let stream = media.getNetStream() else {
            currentStream = nil
            return
        }
        netStreamLockQueue.async {
            stream.mixer.video.drawable = self.streamPreviewView
            stream.mixer.video.externalDisplayDrawable = self.externalDisplayStreamPreviewView
            self.currentStream = stream
            stream.mixer.startRunning()
        }
    }

    func setStreamResolution() {
        var captureSize: CGSize
        var outputSize: CGSize
        switch stream.resolution {
        case .r3840x2160:
            captureSize = .init(width: 3840, height: 2160)
            outputSize = .init(width: 3840, height: 2160)
        case .r2560x1440:
            // Use 4K camera and downscale to 1440p.
            captureSize = .init(width: 3840, height: 2160)
            outputSize = .init(width: 2560, height: 1440)
        case .r1920x1080:
            captureSize = .init(width: 1920, height: 1080)
            outputSize = .init(width: 1920, height: 1080)
        case .r1280x720:
            captureSize = .init(width: 1280, height: 720)
            outputSize = .init(width: 1280, height: 720)
        case .r854x480:
            captureSize = .init(width: 1280, height: 720)
            outputSize = .init(width: 854, height: 480)
        case .r640x360:
            captureSize = .init(width: 1280, height: 720)
            outputSize = .init(width: 640, height: 360)
        case .r426x240:
            captureSize = .init(width: 1280, height: 720)
            outputSize = .init(width: 426, height: 240)
        }
        if stream.portrait {
            outputSize = .init(width: outputSize.height, height: outputSize.width)
        }
        media.setVideoSize(capture: captureSize, output: outputSize)
    }

    private func setStreamCodec() {
        switch stream.codec {
        case .h264avc:
            media.setVideoProfile(profile: kVTProfileLevel_H264_Main_AutoLevel)
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
        media.setStreamAdaptiveResolution(value: stream.adaptiveEncoderResolution)
    }

    private func setStreamKeyFrameInterval() {
        media.setStreamKeyFrameInterval(seconds: stream.maxKeyFrameInterval)
    }

    func isStreamConfigured() -> Bool {
        return stream != fallbackStream
    }

    func isStreamConnected() -> Bool {
        return streamState == .connected
    }

    func isStreaming() -> Bool {
        return streaming
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

    private func makeStreamEndedToast() {
        makeToast(title: String(localized: "🤟 Stream ended 🤟"))
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
        logger.info("stream: Disconnected with reason \(reason)")
        let subTitle = String(localized: "Attempting again in 5 seconds.")
        if streamState == .connected {
            streamTotalBytes += UInt64(media.streamTotal())
            streamingHistoryStream?.numberOfFffffs! += 1
            makeFffffToast(subTitle: subTitle)
        } else if streamState == .connecting {
            makeConnectFailureToast(subTitle: subTitle)
        }
        streamState = .disconnected
        stopNetStream(reconnect: true)
        reconnectTimer = Timer
            .scheduledTimer(withTimeInterval: 5, repeats: false) { _ in
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

    private func handleAudioBuffer(sampleBuffer: CMSampleBuffer) {
        DispatchQueue.main.async {
            self.speechToText.append(sampleBuffer: sampleBuffer)
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
            let speedAndTotal = String(localized: "\(speedString) (\(total))")
            if speedAndTotal != bitrate.speedAndTotal {
                bitrate.speedAndTotal = speedAndTotal
            }
            let bitrateStatusIconColor: Color?
            if speed < stream.bitrate / 5 {
                bitrateStatusIconColor = .red
            } else if speed < stream.bitrate / 2 {
                bitrateStatusIconColor = .orange
            } else {
                bitrateStatusIconColor = nil
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
        media.setConnectionPriorities(connectionPriorities: stream.srt.connectionPriorities!.clone())
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

    private func handleFindVideoFormatError(findVideoFormatError: String, activeFormat: String) {
        makeErrorToastMain(title: findVideoFormatError, subTitle: activeFormat)
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

    func toggleStream() {
        if isLive {
            stopStream()
        } else {
            startStream()
        }
    }

    func setIsLive(value: Bool) {
        isLive = value
        if isWatchLocal() {
            sendIsLiveToWatch(isLive: isLive)
        }
        remoteControlStreamer?.stateChanged(state: RemoteControlState(streaming: isLive))
    }

    func setStreamFps() {
        media.setStreamFps(fps: stream.fps)
    }

    func setStreamPreferAutoFps() {
        media.setStreamPreferAutoFps(value: stream.autoFps)
    }

    func setStreamBitrate(stream: SettingsStream) {
        media.setVideoStreamBitrate(bitrate: stream.bitrate)
        updateStatusStreamText()
    }

    func getBitratePresetByBitrate(bitrate: UInt32) -> SettingsBitratePreset? {
        return database.bitratePresets.first(where: { preset in
            preset.bitrate == bitrate
        })
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
        remoteControlStreamer?.stateChanged(state: RemoteControlState(bitrate: preset.id))
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

    func isShowingStatusStream() -> Bool {
        return database.show.stream && isStreamConfigured()
    }

    func updateBitrateStatus() {
        defer {
            previousBitrateStatusColorSrtDroppedPacketsTotal = media.srtDroppedPacketsTotal
            previousBitrateStatusNumberOfFailedEncodings = numberOfFailedEncodings
        }
        let newBitrateStatusColor: Color
        if media.srtDroppedPacketsTotal > previousBitrateStatusColorSrtDroppedPacketsTotal {
            newBitrateStatusColor = .red
        } else if numberOfFailedEncodings > previousBitrateStatusNumberOfFailedEncodings {
            newBitrateStatusColor = .red
        } else {
            newBitrateStatusColor = .white
        }
        if newBitrateStatusColor != bitrate.statusColor {
            bitrate.statusColor = newBitrateStatusColor
        }
    }

    func updateAdaptiveBitrate() {
        if let (lines, actions) = media.updateAdaptiveBitrate(
            overlay: database.debug.srtOverlay,
            relaxed: relaxedBitrate
        ) {
            latestDebugLines = lines
            latestDebugActions = actions
        }
    }

    func updateAdaptiveBitrateDebug() {
        if database.debug.srtOverlay {
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

extension Model: MediaDelegate {
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

    func mediaOnRistConnected() {
        handleRistConnected()
    }

    func mediaOnRistDisconnected() {
        handleRistDisconnected()
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

    func mediaOnFindVideoFormatError(_ findVideoFormatError: String, _ activeFormat: String) {
        handleFindVideoFormatError(findVideoFormatError: findVideoFormatError, activeFormat: activeFormat)
    }

    func mediaOnAttachCameraError() {
        handleAttachCameraError()
    }

    func mediaOnCaptureSessionError(_ message: String) {
        handleCaptureSessionError(message: message)
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

    func mediaStrlaRelayDestinationAddress(address: String, port: UInt16) {
        moblink.streamer?.startTunnels(address: address, port: port)
    }

    func mediaSetZoomX(x: Float) {
        setZoomX(x: x)
    }

    func mediaSetExposureBias(bias: Float) {
        setExposureBias(bias: bias)
    }

    func mediaSelectedFps(fps: Double, auto: Bool) {
        DispatchQueue.main.async {
            self.selectedFps = Int(fps)
            self.autoFps = auto
            self.updateStatusStreamText()
        }
    }

    func mediaError(error: Error) {
        makeErrorToastMain(title: error.localizedDescription, subTitle: tryGetToastSubTitle(error: error))
    }
}

private func videoCaptureError() -> String {
    return [
        String(localized: "Try to use single or low-energy cameras."),
        String(localized: "Try to lower stream FPS and resolution."),
    ].joined(separator: "\n")
}
