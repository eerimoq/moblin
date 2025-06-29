import CoreLocation
import Foundation
import UIKit

enum RemoteControlAssistantPreviewUser {
    case panel
    case watch
}

extension Model {
    func isShowingStatusRemoteControl() -> Bool {
        return database.show.remoteControl && isAnyRemoteControlConfigured()
    }

    private func isAnyRemoteControlConfigured() -> Bool {
        return isRemoteControlStreamerConfigured() || isRemoteControlAssistantConfigured()
    }

    func clearRemoteControlAssistantLog() {
        remoteControlAssistantLog = []
    }

    func reloadRemoteControlStreamer() {
        remoteControlStreamer?.stop()
        remoteControlStreamer = nil
        guard isRemoteControlStreamerConfigured() else {
            reloadTwitchEventSub()
            reloadChats()
            return
        }
        guard let url = URL(string: database.remoteControl.server.url) else {
            reloadTwitchEventSub()
            reloadChats()
            return
        }
        remoteControlStreamer = RemoteControlStreamer(
            clientUrl: url,
            password: database.remoteControl.password!,
            delegate: self
        )
        remoteControlStreamer!.start()
    }

    private func remoteControlStreamerSendTwitchStart() {
        remoteControlStreamer?.twitchStart(
            channelName: database.debug.reliableChat ? stream.twitchChannelName : nil,
            channelId: stream.twitchChannelId,
            accessToken: stream.twitchAccessToken
        )
    }

    func updateRemoteControlStatus() {
        let status: String
        if isRemoteControlAssistantConnected(), isRemoteControlStreamerConnected() {
            status = String(localized: "Assistant and streamer")
        } else if isRemoteControlAssistantConnected() {
            status = String(localized: "Assistant")
        } else if isRemoteControlStreamerConnected() {
            status = String(localized: "Streamer")
        } else {
            let assistantError = remoteControlAssistant?.connectionErrorMessage ?? ""
            let streamerError = remoteControlStreamer?.connectionErrorMessage ?? ""
            if isRemoteControlAssistantConfigured(), isRemoteControlStreamerConfigured() {
                status = "\(assistantError), \(streamerError)"
            } else if isRemoteControlAssistantConfigured() {
                status = assistantError
            } else if isRemoteControlStreamerConfigured() {
                status = streamerError
            } else {
                status = noValue
            }
        }
        if status != self.status.remoteControlStatus {
            self.status.remoteControlStatus = status
        }
    }

    func isRemoteControlStreamerConfigured() -> Bool {
        let server = database.remoteControl.server
        return server.enabled && !server.url.isEmpty && !database.remoteControl.password!.isEmpty
    }

    func isRemoteControlStreamerConnected() -> Bool {
        return remoteControlStreamer?.isConnected() ?? false
    }

    func stopRemoteControlAssistant() {
        remoteControlAssistant?.stop()
        remoteControlAssistant = nil
    }

    func reloadRemoteControlAssistant() {
        stopRemoteControlAssistant()
        guard isRemoteControlAssistantConfigured() else {
            return
        }
        remoteControlAssistant = RemoteControlAssistant(
            port: database.remoteControl.client.port,
            password: database.remoteControl.password!,
            delegate: self,
            httpProxy: httpProxy(),
            urlSession: urlSession
        )
        remoteControlAssistant!.start()
    }

    func isRemoteControlAssistantConnected() -> Bool {
        return remoteControlAssistant?.isConnected() ?? false
    }

    func updateRemoteControlAssistantStatus() {
        guard showingRemoteControl || isWatchRemoteControl(), isRemoteControlAssistantConnected() else {
            return
        }
        remoteControlAssistant?.getStatus { general, topLeft, topRight in
            self.remoteControl.general = general
            self.remoteControl.topLeft = topLeft
            self.remoteControl.topRight = topRight
            if self.isWatchRemoteControl() {
                self.sendRemoteControlAssistantStatusToWatch()
            }
        }
        remoteControlAssistant?.getSettings { settings in
            self.remoteControl.settings = settings
        }
    }

    func isRemoteControlAssistantConfigured() -> Bool {
        let client = database.remoteControl.client
        return client.enabled && client.port > 0 && !database.remoteControl.password!.isEmpty
    }

    func remoteControlAssistantSetRemoteSceneSettings() {
        let data = RemoteControlRemoteSceneSettings(
            scenes: database.scenes,
            widgets: database.widgets,
            selectedSceneId: database.remoteSceneId
        )
        remoteControlAssistant?.setRemoteSceneSettings(data: data) {}
    }

    private func shouldSendRemoteScene() -> Bool {
        return database.remoteSceneId != nil && remoteControlAssistant?.isConnected() == true
    }

    func remoteControlAssistantSetRemoteSceneDataTextStats(stats: TextEffectStats) {
        guard shouldSendRemoteScene() else {
            return
        }
        let data = RemoteControlRemoteSceneData(textStats: RemoteControlRemoteSceneDataTextStats(stats: stats))
        remoteControlAssistant?.setRemoteSceneData(data: data) {}
    }

    func remoteControlAssistantSetRemoteSceneDataLocation(location: CLLocation) {
        guard shouldSendRemoteScene() else {
            return
        }
        let data = RemoteControlRemoteSceneData(location: RemoteControlRemoteSceneDataLocation(location: location))
        remoteControlAssistant?.setRemoteSceneData(data: data) {}
    }

    func remoteControlAssistantSetStream(on: Bool) {
        remoteControlAssistant?.setStream(on: on) {
            DispatchQueue.main.async {
                self.updateRemoteControlAssistantStatus()
            }
        }
    }

    func remoteControlAssistantSetRecord(on: Bool) {
        remoteControlAssistant?.setRecord(on: on) {
            DispatchQueue.main.async {
                self.updateRemoteControlAssistantStatus()
            }
        }
    }

    func remoteControlAssistantSetMute(on: Bool) {
        remoteControlAssistant?.setMute(on: on) {
            DispatchQueue.main.async {
                self.updateRemoteControlAssistantStatus()
            }
        }
    }

    func remoteControlAssistantSetScene(id: UUID) {
        remoteControlAssistant?.setScene(id: id) {
            DispatchQueue.main.async {
                self.updateRemoteControlAssistantStatus()
            }
        }
    }

    func remoteControlAssistantSetMic(id: String) {
        remoteControlAssistant?.setMic(id: id) {
            DispatchQueue.main.async {
                self.updateRemoteControlAssistantStatus()
            }
        }
    }

    func remoteControlAssistantSetZoom(x: Float) {
        remoteControlAssistant?.setZoom(x: x) {
            DispatchQueue.main.async {
                self.updateRemoteControlAssistantStatus()
            }
        }
    }

    func remoteControlAssistantSetBitratePreset(id: UUID) {
        remoteControlAssistant?.setBitratePreset(id: id) {
            DispatchQueue.main.async {
                self.updateRemoteControlAssistantStatus()
            }
        }
    }

    func remoteControlAssistantSetDebugLogging(on: Bool) {
        remoteControlAssistant?.setDebugLogging(on: on) {}
    }

    func remoteControlAssistantReloadBrowserWidgets() {
        remoteControlAssistant?.reloadBrowserWidgets {
            DispatchQueue.main.async {
                self.makeToast(title: String(localized: "Browser widgets reloaded"))
            }
        }
    }

    func remoteControlAssistantSetSrtConnectionPriorityEnabled(enabled: Bool) {
        remoteControlAssistant?.setSrtConnectionPrioritiesEnabled(
            enabled: enabled
        ) {}
    }

    func remoteControlAssistantSetSrtConnectionPriority(priority: RemoteControlSettingsSrtConnectionPriority) {
        remoteControlAssistant?.setSrtConnectionPriority(
            id: priority.id,
            priority: priority.priority,
            enabled: priority.enabled
        ) {}
    }

    func remoteControlAssistantStartPreview(user: RemoteControlAssistantPreviewUser) {
        remoteControlAssistantPreviewUsers.insert(user)
        remoteControlAssistant?.startPreview()
    }

    func remoteControlAssistantStopPreview(user: RemoteControlAssistantPreviewUser) {
        remoteControlAssistantPreviewUsers.remove(user)
        if remoteControlAssistantPreviewUsers.isEmpty {
            remoteControlAssistant?.stopPreview()
        }
    }

    func remoteControlAssistantStartStatus() {
        remoteControlAssistant?.startStatus()
    }

    func remoteControlAssistantStopStatus() {
        remoteControlAssistant?.stopStatus()
    }

    func reloadRemoteControlRelay() {
        remoteControlRelay?.stop()
        remoteControlRelay = nil
        guard isRemoteControlRelayConfigured() else {
            return
        }
        guard let assistantUrl = URL(string: "ws://localhost:\(database.remoteControl.client.port)") else {
            return
        }
        remoteControlRelay = RemoteControlRelay(
            baseUrl: database.remoteControl.client.relay!.baseUrl,
            bridgeId: database.remoteControl.client.relay!.bridgeId,
            assistantUrl: assistantUrl
        )
        remoteControlRelay?.start()
    }

    func isRemoteControlRelayConfigured() -> Bool {
        let relay = database.remoteControl.client.relay!
        return relay.enabled && !relay.baseUrl.isEmpty
    }

    func remoteControlStreamerCreateStatus(filter: RemoteControlStartStatusFilter?)
        -> (RemoteControlStatusGeneral?, RemoteControlStatusTopLeft?, RemoteControlStatusTopRight?)
    {
        var general: RemoteControlStatusGeneral?
        var topLeft: RemoteControlStatusTopLeft?
        var topRight: RemoteControlStatusTopRight?
        if let filter {
            if filter.topRight {
                topRight = remoteControlStreamerCreateStatusTopRight()
            }
        } else {
            general = remoteControlStreamerCreateStatusGeneral()
            topLeft = remoteControlStreamerCreateStatusTopLeft()
            topRight = remoteControlStreamerCreateStatusTopRight()
        }
        return (general, topLeft, topRight)
    }

    private func remoteControlStreamerCreateStatusGeneral() -> RemoteControlStatusGeneral {
        var general = RemoteControlStatusGeneral()
        general.batteryCharging = isBatteryCharging()
        general.batteryLevel = Int(100 * battery.level)
        switch status.thermalState {
        case .nominal:
            general.flame = .white
        case .fair:
            general.flame = .white
        case .serious:
            general.flame = .yellow
        case .critical:
            general.flame = .red
        @unknown default:
            general.flame = .red
        }
        general.wiFiSsid = currentWiFiSsid
        general.isLive = isLive
        general.isRecording = isRecording
        general.isMuted = isMuteOn
        return general
    }

    private func remoteControlStreamerCreateStatusTopLeft() -> RemoteControlStatusTopLeft {
        var topLeft = RemoteControlStatusTopLeft()
        if isStreamConfigured() {
            topLeft.stream = RemoteControlStatusItem(message: status.streamText)
        }
        topLeft.camera = RemoteControlStatusItem(message: status.statusCameraText)
        topLeft.mic = RemoteControlStatusItem(message: currentMic.name)
        if zoom.hasZoom {
            topLeft.zoom = RemoteControlStatusItem(message: zoom.statusText())
        }
        if isObsRemoteControlConfigured() {
            topLeft.obs = RemoteControlStatusItem(message: status.statusObsText)
        }
        if isEventsConfigured() {
            topLeft.events = RemoteControlStatusItem(message: status.statusEventsText)
        }
        if isChatConfigured() {
            topLeft.chat = RemoteControlStatusItem(message: status.statusChatText)
        }
        if isViewersConfigured() && isLive {
            topLeft.viewers = RemoteControlStatusItem(message: statusViewersText())
        }
        return topLeft
    }

    private func remoteControlStreamerCreateStatusTopRight() -> RemoteControlStatusTopRight {
        var topRight = RemoteControlStatusTopRight()
        let level = formatAudioLevel(level: audio.level) +
            formatAudioLevelChannels(channels: audio.numberOfChannels)
        topRight.audioLevel = RemoteControlStatusItem(message: level)
        topRight.audioInfo = .init(
            audioLevel: .unknown,
            numberOfAudioChannels: audio.numberOfChannels
        )
        if audio.level.isNaN {
            topRight.audioInfo!.audioLevel = .muted
        } else if audio.level.isInfinite {
            topRight.audioInfo!.audioLevel = .unknown
        } else {
            topRight.audioInfo!.audioLevel = .value(audio.level)
        }
        if isServersConfigured() {
            topRight.rtmpServer = RemoteControlStatusItem(message: servers.speedAndTotal)
        }
        if isAnyRemoteControlConfigured() {
            topRight.remoteControl = RemoteControlStatusItem(message: status.remoteControlStatus)
        }
        if isGameControllerConnected() {
            topRight.gameController = RemoteControlStatusItem(message: status.gameControllersTotal)
        }
        if isLive {
            topRight.bitrate = RemoteControlStatusItem(message: bitrate.speedAndTotal)
        }
        if isLive {
            topRight.uptime = RemoteControlStatusItem(message: streamUptime.uptime)
        }
        if isLocationEnabled() {
            topRight.location = RemoteControlStatusItem(message: status.location)
        }
        if isStatusBondingActive() {
            topRight.srtla = RemoteControlStatusItem(message: bonding.statistics)
        }
        if isStatusBondingRttsActive() {
            topRight.srtlaRtts = RemoteControlStatusItem(message: bonding.rtts)
        }
        if isRecording {
            topRight.recording = RemoteControlStatusItem(message: recording.length)
        }
        if stream.replay.enabled {
            topRight.replay = RemoteControlStatusItem(message: String(localized: "Enabled"))
        }
        if isStatusBrowserWidgetsActive() {
            topRight.browserWidgets = RemoteControlStatusItem(message: status.browserWidgetsStatus)
        }
        if isAnyMoblinkConfigured() {
            topRight.moblink = RemoteControlStatusItem(message: moblink.status)
        }
        if !status.djiDevicesStatus.isEmpty {
            topRight.djiDevices = RemoteControlStatusItem(message: status.djiDevicesStatus)
        }
        return topRight
    }

    func sendPeriodicRemoteControlStreamerStatus() {
        guard isRemoteControlStreamerConnected(), isRemoteControlAssistantRequestingStatus else {
            return
        }
        let (general,
             topLeft,
             topRight) = remoteControlStreamerCreateStatus(filter: remoteControlAssistantRequestingStatusFilter)
        remoteControlStreamer?.sendStatus(general: general, topLeft: topLeft, topRight: topRight)
    }
}

extension Model: RemoteControlStreamerDelegate {
    func remoteControlStreamerConnected() {
        makeToast(
            title: String(localized: "Remote control assistant connected"),
            subTitle: String(localized: "Reliable alerts and chat messages activated")
        )
        useRemoteControlForChatAndEvents = true
        reloadTwitchEventSub()
        reloadChats()
        isRemoteControlAssistantRequestingPreview = false
        isRemoteControlAssistantRequestingStatus = false
        remoteControlStreamerSendTwitchStart()
        setLowFpsImage()
        updateRemoteControlStatus()
        var state = RemoteControlState()
        if sceneSelector.sceneIndex < enabledScenes.count {
            state.scene = enabledScenes[sceneSelector.sceneIndex].id
        }
        state.mic = currentMic.id
        if let preset = getBitratePresetByBitrate(bitrate: stream.bitrate) {
            state.bitrate = preset.id
        }
        state.zoom = zoom.x
        state.debugLogging = database.debug.logLevel == .debug
        state.streaming = isLive
        state.recording = isRecording
        remoteControlStreamer?.stateChanged(state: state)
    }

    func remoteControlStreamerDisconnected() {
        makeToast(title: String(localized: "Remote control assistant disconnected"))
        isRemoteControlAssistantRequestingPreview = false
        isRemoteControlAssistantRequestingStatus = false
        setLowFpsImage()
        updateRemoteControlStatus()
    }

    func remoteControlStreamerGetStatus()
        -> (RemoteControlStatusGeneral, RemoteControlStatusTopLeft, RemoteControlStatusTopRight)
    {
        let (general, topLeft, topRight) = remoteControlStreamerCreateStatus(filter: nil)
        return (general!, topLeft!, topRight!)
    }

    func remoteControlStreamerGetSettings() -> RemoteControlSettings {
        let scenes = enabledScenes.map { scene in
            RemoteControlSettingsScene(id: scene.id, name: scene.name)
        }
        let mics = mics.map { mic in
            RemoteControlSettingsMic(id: mic.id, name: mic.name)
        }
        let bitratePresets = database.bitratePresets.map { preset in
            RemoteControlSettingsBitratePreset(id: preset.id, bitrate: preset.bitrate)
        }
        let connectionPriorities = stream.srt.connectionPriorities!.priorities
            .map { priority in
                RemoteControlSettingsSrtConnectionPriority(
                    id: priority.id,
                    name: priority.name,
                    priority: priority.priority,
                    enabled: priority.enabled!
                )
            }
        let connectionPrioritiesEnabled = stream.srt.connectionPriorities!.enabled
        return RemoteControlSettings(
            scenes: scenes,
            bitratePresets: bitratePresets,
            mics: mics,
            srt: RemoteControlSettingsSrt(
                connectionPrioritiesEnabled: connectionPrioritiesEnabled,
                connectionPriorities: connectionPriorities
            )
        )
    }

    func remoteControlStreamerSetScene(id: UUID) {
        selectScene(id: id)
    }

    func remoteControlStreamerSetMic(id: String) {
        selectMicById(id: id)
    }

    func remoteControlStreamerSetBitratePreset(id: UUID) {
        guard let preset = database.bitratePresets.first(where: { preset in
            preset.id == id
        }) else {
            return
        }
        setBitrate(bitrate: preset.bitrate)
    }

    func remoteControlStreamerSetRecord(on: Bool) {
        if on {
            startRecording()
        } else {
            stopRecording()
        }
        updateQuickButtonStates()
    }

    func remoteControlStreamerSetStream(on: Bool) {
        if on {
            startStream()
        } else {
            stopStream()
        }
        updateQuickButtonStates()
    }

    func remoteControlStreamerSetDebugLogging(on: Bool) {
        setDebugLogging(on: on)
    }

    func remoteControlStreamerSetZoom(x: Float) {
        setZoomX(x: x, rate: database.zoom.speed!)
    }

    func remoteControlStreamerSetMute(on: Bool) {
        setMuteOn(value: on)
    }

    func remoteControlStreamerSetTorch(on: Bool) {
        streamOverlay.isTorchOn = on
        updateTorch()
        toggleGlobalButton(type: .torch)
        updateQuickButtonStates()
    }

    func remoteControlStreamerReloadBrowserWidgets() {
        reloadBrowserWidgets()
    }

    func remoteControlStreamerSetSrtConnectionPrioritiesEnabled(enabled: Bool) {
        stream.srt.connectionPriorities!.enabled = enabled
        updateSrtlaPriorities()
    }

    func remoteControlStreamerSetSrtConnectionPriority(
        id: UUID,
        priority: Int,
        enabled: Bool
    ) {
        if let entry = stream.srt.connectionPriorities!.priorities.first(where: { $0.id == id }) {
            entry.priority = clampConnectionPriority(value: priority)
            entry.enabled = enabled
            updateSrtlaPriorities()
        }
    }

    func sendPreviewToRemoteControlAssistant(preview: Data) {
        guard isRemoteControlStreamerConnected() else {
            return
        }
        remoteControlStreamer?.sendPreview(preview: preview)
    }

    func remoteControlStreamerTwitchEventSubNotification(message: String) {
        twitchEventSub?.handleMessage(messageText: message)
    }

    func remoteControlStreamerChatMessages(history: Bool, messages: [RemoteControlChatMessage]) {
        let live = !history || remoteControlStreamerLatestReceivedChatMessageId != -1
        for message in messages where message.id > remoteControlStreamerLatestReceivedChatMessageId {
            appendChatMessage(platform: message.platform,
                              messageId: message.messageId,
                              user: message.user,
                              userId: message.userId,
                              userColor: message.userColor,
                              userBadges: message.userBadges,
                              segments: message.segments,
                              timestamp: message.timestamp,
                              timestampTime: .now,
                              isAction: message.isAction,
                              isSubscriber: message.isSubscriber,
                              isModerator: message.isModerator,
                              bits: message.bits,
                              highlight: nil,
                              live: live)
            remoteControlStreamerLatestReceivedChatMessageId = message.id
        }
    }

    func remoteControlStreamerStartPreview() {
        isRemoteControlAssistantRequestingPreview = true
        setLowFpsImage()
    }

    func remoteControlStreamerStopPreview() {
        isRemoteControlAssistantRequestingPreview = false
        setLowFpsImage()
    }

    func remoteControlStreamerSetRemoteSceneSettings(data: RemoteControlRemoteSceneSettings) {
        let (scenes, widgets, selectedSceneId) = data.toSettings()
        if let selectedSceneId {
            let widget = SettingsWidget(name: "")
            widget.type = .scene
            widget.scene.sceneId = selectedSceneId
            remoteSceneScenes = scenes
            remoteSceneWidgets = [widget] + widgets
            resetSelectedScene(changeScene: false)
        } else if !remoteSceneScenes.isEmpty {
            remoteSceneScenes = []
            remoteSceneWidgets = []
            resetSelectedScene(changeScene: false)
        }
    }

    func remoteControlStreamerSetRemoteSceneData(data: RemoteControlRemoteSceneData) {
        if let textStats = data.textStats {
            remoteSceneData.textStats = textStats
        }
        if let location = data.location {
            remoteSceneData.location = location
        }
    }

    func remoteControlStreamerInstantReplay() {
        instantReplay()
    }

    func remoteControlStreamerSaveReplay() {
        _ = saveReplay()
    }

    func clearRemoteSceneSettingsAndData() {
        remoteSceneScenes = []
        remoteSceneWidgets = []
        remoteSceneData.textStats = nil
        remoteSceneData.location = nil
    }

    func remoteControlStreamerStartStatus(interval _: Int, filter: RemoteControlStartStatusFilter) {
        isRemoteControlAssistantRequestingStatus = true
        remoteControlAssistantRequestingStatusFilter = filter
    }

    func remoteControlStreamerStopStatus() {
        isRemoteControlAssistantRequestingStatus = false
        remoteControlAssistantRequestingStatusFilter = nil
    }
}

extension Model: RemoteControlAssistantDelegate {
    func remoteControlAssistantConnected() {
        makeToast(title: String(localized: "Remote control streamer connected"))
        updateRemoteControlStatus()
        updateRemoteControlAssistantStatus()
        remoteControlAssistantSetRemoteSceneSettings()
    }

    func remoteControlAssistantDisconnected() {
        makeToast(title: String(localized: "Remote control streamer disconnected"))
        remoteControl.topLeft = nil
        remoteControl.topRight = nil
        updateRemoteControlStatus()
    }

    func remoteControlAssistantStateChanged(state: RemoteControlState) {
        if let scene = state.scene {
            remoteControlState.scene = scene
            remoteControl.scene = scene
        }
        if let mic = state.mic {
            remoteControlState.mic = mic
            remoteControl.mic = mic
        }
        if let bitrate = state.bitrate {
            remoteControlState.bitrate = bitrate
            remoteControl.bitrate = bitrate
        }
        if let zoom = state.zoom {
            remoteControlState.zoom = zoom
            remoteControl.zoom = String(zoom)
        }
        if let debugLogging = state.debugLogging {
            remoteControlState.debugLogging = debugLogging
            remoteControl.debugLogging = debugLogging
        }
        if let streaming = state.streaming {
            remoteControlState.streaming = streaming
            remoteControl.streaming = streaming
        }
        if let recording = state.recording {
            remoteControlState.recording = recording
            remoteControl.recording = recording
        }
        if isWatchRemoteControl() {
            sendRemoteControlAssistantStatusToWatch()
        }
    }

    func remoteControlAssistantPreview(preview: Data) {
        remoteControl.preview = UIImage(data: preview)
        if isWatchRemoteControl() {
            sendPreviewToWatch(image: preview)
        }
    }

    func remoteControlAssistantLog(entry: String) {
        if remoteControlAssistantLog.count > 100_000 {
            remoteControlAssistantLog.removeFirst()
        }
        logId += 1
        remoteControlAssistantLog.append(LogEntry(id: logId, message: entry))
    }

    func remoteControlAssistantStatus(general _: RemoteControlStatusGeneral?,
                                      topLeft _: RemoteControlStatusTopLeft?,
                                      topRight: RemoteControlStatusTopRight?)
    {
        if let topRight {
            remoteControl.topRight = topRight
        }
    }
}
