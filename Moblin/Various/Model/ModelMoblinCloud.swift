import Foundation

private func makeMoblinCloudUrl(key: String) -> URL? {
    guard var components = URLComponents(string: moblinWebsiteApiUrl) else {
        return nil
    }
    switch components.scheme {
    case "https":
        components.scheme = "wss"
    case "http":
        components.scheme = "ws"
    default:
        return nil
    }
    guard let key = key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
        return nil
    }
    components.percentEncodedPath += "/remote-control/streamer/\(key)"
    return components.url
}

extension Model {
    func reloadMoblinCloud() {
        moblinCloud?.stop()
        moblinCloud = nil
        let settings = database.moblinCloud
        let key = settings.key.trim()
        guard settings.enabled, !key.isEmpty, let url = makeMoblinCloudUrl(key: key) else {
            updateMoblinCloudStatus()
            return
        }
        moblinCloud = MoblinCloud(model: self, url: url, streamerId: getRemoteControlStreamerId())
        moblinCloud?.start()
        updateMoblinCloudStatus()
    }

    func isShowingStatusMoblinCloud() -> Bool {
        database.show.moblinCloud && database.moblinCloud.enabled
    }

    func updateMoblinCloudStatus() {
        let ok = moblinCloud?.isConnected() ?? false
        let status: String = if ok {
            String(localized: "Connected")
        } else if let moblinCloud {
            moblinCloud.connectionErrorMessage()
        } else {
            noValue
        }
        if status != statusTopRight.moblinCloudStatus {
            statusTopRight.moblinCloudStatus = status
        }
        if ok != statusTopRight.moblinCloudOk {
            statusTopRight.moblinCloudOk = ok
        }
    }

    func getMoblinCloudWheelOfLuckWidget() -> SettingsWidget? {
        guard let id = database.moblinCloud.wheelOfLuckWidgetId else {
            return nil
        }
        return database.widgets.first(where: { $0.id == id && $0.type == .wheelOfLuck })
    }

    func isMoblinCloudWheelOfLuckWidget(widget: SettingsWidget) -> Bool {
        widget.id == database.moblinCloud.wheelOfLuckWidgetId
    }

    func moblinCloudSendWheelOfLuck() {
        let wheel = getMoblinCloudWheelOfLuckWidget().map {
            RemoteControlWheelOfLuck(options: $0.wheelOfLuck.options.map {
                RemoteControlWheelOfLuckOption(text: $0.text, weight: $0.weight)
            })
        }
        moblinCloud?.sendWheelOfLuck(wheel: wheel)
    }

    func moblinCloudSendSongRequests() {
        moblinCloud?.sendSongRequests(enabled: database.moblinCloud.songRequests)
    }

    func moblinCloudSpinWheelOfLuck(name: String, message: String, count: Int, requestId: String?) {
        guard !isRemoteControlRequestAlreadyHandled(requestId: requestId),
              let widget = getMoblinCloudWheelOfLuckWidget()
        else {
            return
        }
        getWheelOfLuckEffect(id: widget.id)?.spin(name: name, message: message, count: min(max(count, 1), 10))
    }
}

@MainActor
class MoblinCloud {
    private weak var model: Model?
    private var streamer: RemoteControlStreamer?

    init(model: Model, url: URL, streamerId: String) {
        self.model = model
        streamer = RemoteControlStreamer(clientUrl: url, password: "", streamerId: streamerId, delegate: self)
    }

    func start() {
        streamer?.start()
    }

    func stop() {
        streamer?.stop()
        streamer = nil
    }

    func isConnected() -> Bool {
        streamer?.isConnected() ?? false
    }

    func connectionErrorMessage() -> String {
        streamer?.connectionErrorMessage ?? ""
    }

    func sendWheelOfLuck(wheel: RemoteControlWheelOfLuck?) {
        streamer?.sendWheelOfLuck(wheel: wheel)
    }

    func sendSongRequests(enabled: Bool) {
        streamer?.sendSongRequests(enabled: enabled)
    }
}

extension MoblinCloud: RemoteControlStreamerDelegate {
    func remoteControlStreamerConnected() {
        model?.makeToast(title: String(localized: "Moblin Cloud connected"))
        model?.updateMoblinCloudStatus()
        model?.moblinCloudSendWheelOfLuck()
        model?.moblinCloudSendSongRequests()
    }

    func remoteControlStreamerDisconnected() {
        model?.makeToast(title: String(localized: "Moblin Cloud disconnected"))
        model?.updateMoblinCloudStatus()
    }

    func remoteControlStreamerWrongPassword() {}

    func remoteControlStreamerGetStatus()
        -> (RemoteControlStatusGeneral, RemoteControlStatusTopLeft, RemoteControlStatusTopRight)
    {
        (.init(), .init(), .init())
    }

    func remoteControlStreamerGetSettings() -> RemoteControlSettings {
        RemoteControlSettings(streams: [],
                              scenes: [],
                              autoSceneSwitchers: nil,
                              bitratePresets: [],
                              mics: [],
                              srt: .init(connectionPrioritiesEnabled: false, connectionPriorities: []))
    }

    func remoteControlStreamerSetStream(id _: UUID) {}

    func remoteControlStreamerSetScene(id _: UUID) {}

    func remoteControlStreamerSetAutoSceneSwitcher(id _: UUID?) {}

    func remoteControlStreamerSetMic(id _: String) {}

    func remoteControlStreamerSetTalkbackMic(id _: String) {}

    func remoteControlStreamerSetBitratePreset(id _: UUID) {}

    func remoteControlStreamerSetRecord(on _: Bool) {}

    func remoteControlStreamerSetLive(on _: Bool) {}

    func remoteControlStreamerSetPreviewStream(on _: Bool) {}

    func remoteControlStreamerSetDebugLogging(on _: Bool) {}

    func remoteControlStreamerSetZoom(x _: Float) {}

    func remoteControlStreamerSetZoomPreset(id _: UUID) {}

    func remoteControlStreamerSetMute(on _: Bool) {}

    func remoteControlStreamerSetStealthMode(on _: Bool) {}

    func remoteControlStreamerSetTorch(on _: Bool) {}

    func remoteControlStreamerReloadBrowserWidgets() {}

    func remoteControlStreamerSetSrtConnectionPriority(id _: UUID, priority _: Int, enabled _: Bool) {}

    func remoteControlStreamerSetSrtConnectionPrioritiesEnabled(enabled _: Bool) {}

    func remoteControlStreamerTwitchEventSubNotification(message _: String) {}

    func remoteControlStreamerChatMessages(history _: Bool, messages _: [RemoteControlChatMessage]) {}

    func remoteControlStreamerStartPreview() {}

    func remoteControlStreamerStopPreview() {}

    func remoteControlStreamerSetRemoteSceneSettings(data _: RemoteControlRemoteSceneSettings) {}

    func remoteControlStreamerSetRemoteSceneData(data _: RemoteControlRemoteSceneData) {}

    func remoteControlStreamerInstantReplay() {}

    func remoteControlStreamerSaveReplay() {}

    func remoteControlStreamerStartStatus(interval _: Int, filter _: RemoteControlStartStatusFilter) {}

    func remoteControlStreamerStopStatus() {}

    func remoteControlStreamerGetScoreboardSports() -> [String] {
        []
    }

    func remoteControlStreamerSetScoreboardSport(sportId _: String) {}

    func remoteControlStreamerUpdateScoreboard(config _: RemoteControlScoreboardMatchConfig) {}

    func remoteControlStreamerToggleScoreboardClock() {}

    func remoteControlStreamerSetScoreboardDuration(minutes _: Int) {}

    func remoteControlStreamerSetScoreboardClock(time _: String) {}

    func remoteControlStreamerWhip(url _: String,
                                   method _: String,
                                   headers _: [SettingsHttpHeader],
                                   body _: Data,
                                   onCompleted: @escaping (Int, [SettingsHttpHeader], Data) -> Void)
    {
        onCompleted(404, [], Data())
    }

    func remoteControlStreamerSetFilter(filter _: RemoteControlFilter, on _: Bool) {}

    func remoteControlStreamerTriggerReaction(reaction _: RemoteControlReaction) {}

    func remoteControlStreamerMoveToGimbalPreset(id _: UUID) {}

    func remoteControlStreamerSetGimbalTracking(on _: Bool) {}

    func remoteControlStreamerSetGimbalMovement(x _: Float, y _: Float) {}

    func remoteControlStreamerAnimateGimbal(motion _: SettingsGimbalMotion) {}

    func remoteControlStreamerSaveGimbalPreset() {}

    func remoteControlStreamerImportSettings(settings _: Data, onCompleted: @escaping (Bool) -> Void) {
        onCompleted(false)
    }

    func remoteControlStreamerStartStats(filter _: RemoteControlStartStatsFilter?) {}

    func remoteControlStreamerStopStats() {}

    func remoteControlStreamerStartMacro(id _: UUID) {}

    func remoteControlStreamerStopMacro(id _: UUID) {}

    func remoteControlStreamerSendMessage(text _: String) {}

    func remoteControlStreamerMusic(command: RemoteControlMusicCommand,
                                    onCompleted: @escaping (RemoteControlResult, RemoteControlResponse?)
                                        -> Void)
    {
        switch command {
        case .status, .find, .add:
            guard let model else {
                onCompleted(.error, nil)
                return
            }
            model.remoteControlStreamerMusic(command: command, onCompleted: onCompleted)
        default:
            onCompleted(.error, nil)
        }
    }

    func remoteControlStreamerSpinWheelOfLuck(name: String, message: String, count: Int, requestId: String?) {
        model?.moblinCloudSpinWheelOfLuck(name: name, message: message, count: count, requestId: requestId)
    }

    func remoteControlStreamerTip(name: String,
                                  message: String,
                                  amount: String,
                                  currency: String,
                                  requestId: String)
    {
        model?.remoteControlStreamerTip(name: name,
                                        message: message,
                                        amount: amount,
                                        currency: currency,
                                        requestId: requestId)
    }
}
