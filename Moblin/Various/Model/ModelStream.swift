import AVFoundation
import Foundation
import SwiftUI
import VideoToolbox

private let lowPowerBitrate: UInt32 = 2_000_000

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
    var kickAccessToken = ""
    var kickLoggedIn: Bool = false
    @Published var youTubeHandle = ""
    @Published var soopChannelName = ""
    @Published var soopStreamId = ""
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
        streamingHistoryStream!.updateHighestThermalState(thermalState: ThermalState(from: statusOther.thermalState))
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
            streamingHistoryStream.numberOfChatMessages = streamTotalChatMessages
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
        startNetStreamSingleTrack()
    }

    private func startNetStreamSingleTrack() {
        switch stream.getProtocol() {
        case .rtmp:
            media.rtmpStartStream(url: stream.url,
                                  targetBitrate: getBitrate(),
                                  adaptiveBitrate: stream.rtmp.adaptiveBitrateEnabled)
            updateAdaptiveBitrateRtmpIfEnabled()
        case .srt:
            payloadSize = stream.srt.mpegtsPacketsPerPacket * MpegTsPacket.size
            media.srtStartStream(
                isSrtla: stream.isSrtla(),
                url: stream.url,
                reconnectTime: 5,
                targetBitrate: getBitrate(),
                adaptiveBitrateAlgorithm: stream.srt.adaptiveBitrateEnabled
                    ? stream.srt.adaptiveBitrate.algorithm
                    : nil,
                latency: stream.srt.latency,
                overheadBandwidth: database.debug.srtOverheadBandwidth,
                maximumBandwidthFollowInput: database.debug.maximumBandwidthFollowInput,
                mpegtsPacketsPerPacket: stream.srt.mpegtsPacketsPerPacket,
                networkInterfaceNames: database.networkInterfaceNames,
                connectionPriorities: stream.srt.connectionPriorities,
                dnsLookupStrategy: stream.srt.dnsLookupStrategy
            )
            updateAdaptiveBitrateSrt(stream: stream)
        case .rist:
            media.ristStartStream(url: stream.url,
                                  bonding: stream.rist.bonding,
                                  targetBitrate: getBitrate(),
                                  adaptiveBitrate: stream.rist.adaptiveBitrateEnabled)
            updateAdaptiveBitrateRistIfEnabled()
        }
        updateSpeed(now: .now)
    }

    private func stopNetStream() {
        moblink.streamer?.stopTunnels()
        reconnectTimer.stop()
        media.rtmpStopStream()
        media.srtStopStream()
        media.ristStopStream()
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
        return database.streams.first { stream in
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
        setAudioStreamBitrate(stream: stream)
        setAudioStreamFormat(format: stream.audioCodec.toEncoder())
        setAudioChannelsMap(channelsMap: [
            0: database.audio.audioOutputToInputChannelsMap.channel1,
            1: database.audio.audioOutputToInputChannelsMap.channel2,
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
            builtinAudioDelay: database.debug.builtinAudioAndVideoDelay,
            destinations: stream.multiStreaming.destinations,
            newSrt: database.debug.newSrt
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
            self.processor = processor
            processor.startRunning()
        }
    }

    func setStreamResolution() {
        let resolution: SettingsStreamResolution
        if stream.recording.overrideStream {
            if stream.recording.resolution > stream.resolution {
                resolution = stream.recording.resolution
            } else {
                resolution = stream.resolution
            }
        } else {
            resolution = stream.resolution
        }
        var captureSize: CGSize
        switch resolution {
        case .r4032x3024:
            captureSize = .init(width: 4032, height: 3024)
        case .r3840x2160:
            captureSize = .init(width: 3840, height: 2160)
        case .r2560x1440:
            // Use 4K camera and downscale to 1440p.
            captureSize = .init(width: 3840, height: 2160)
        case .r1920x1440:
            captureSize = .init(width: 1920, height: 1440)
        case .r1920x1080:
            captureSize = .init(width: 1920, height: 1080)
        case .r1024x768:
            captureSize = .init(width: 1024, height: 768)
        case .r1280x720:
            captureSize = .init(width: 1280, height: 720)
        case .r960x540:
            captureSize = .init(width: 960, height: 540)
        case .r854x480:
            // Use 540p camera and downscale to 480p.
            captureSize = .init(width: 960, height: 540)
        case .r640x360:
            // Use 540p camera and downscale to 360p.
            captureSize = .init(width: 960, height: 540)
        case .r426x240:
            // Use 540p camera and downscale to 240p.
            captureSize = .init(width: 960, height: 540)
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
            let speedAndTotal: String
            if numberOfDestinations == 1 {
                speedAndTotal = String(localized: "\(speedString) (\(total))")
            } else {
                speedAndTotal = String(localized: "\(speedString) x\(numberOfDestinations) (\(total))")
            }
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
        if let stream = getRtmpStream(id: cameraId) {
            isNetwork = true
            stream.connected = true
        } else if let stream = getSrtlaStream(id: cameraId) {
            isNetwork = true
            stream.connected = true
        } else if let stream = getRistStream(id: cameraId) {
            isNetwork = true
            stream.connected = true
        }
        if isNetwork {
            markMicAsConnected(id: "\(cameraId) 0")
            switchMicIfNeededAfterNetworkCameraChange()
        }
        updateDisconnectProtectionVideoSourceConnected()
    }

    private func handleBufferedVideoRemoved(cameraId: UUID) {
        activeBufferedVideoIds.remove(cameraId)
        var isNetwork = false
        if let stream = getRtmpStream(id: cameraId) {
            isNetwork = true
            stream.connected = false
        } else if let stream = getSrtlaStream(id: cameraId) {
            isNetwork = true
            stream.connected = false
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
            self.currentFps = fps
            self.updateStatusStreamText()
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
        if isWatchLocal() {
            sendIsLiveToWatch(isLive: isLive)
        }
        remoteControlStreamer?.stateChanged(state: RemoteControlState(streaming: isLive))
    }

    func setStreamFps(fps: Int? = nil) {
        media.setFps(fps: fps ?? stream.fps, preferAutoFps: stream.autoFps)
    }

    func setStreamBitrate(stream: SettingsStream) {
        media.setVideoStreamBitrate(bitrate: stream.bitrate)
        updateStatusStreamText()
    }

    func getBitratePresetByBitrate(bitrate: UInt32) -> SettingsBitratePreset? {
        return database.bitratePresets.first(where: { $0.bitrate == bitrate })
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

    private func getBitrate() -> UInt32 {
        return statusTopRight.isLowPowerMode ? lowPowerBitrate : stream.bitrate
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
            self.autoFps = auto
            self.updateStatusStreamText()
        }
    }

    func mediaError(error: Error) {
        makeErrorToastMain(title: error.localizedDescription, subTitle: tryGetToastSubTitle(error: error))
    }
}

private func videoCaptureError() -> String {
    return String(localized: "Try to use single or low-energy cameras.")
}
