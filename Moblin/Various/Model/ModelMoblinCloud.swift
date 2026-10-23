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
    func stopMoblinCloud() {
        moblinCloud?.stop()
        moblinCloud = nil
    }

    func reloadMoblinCloud() {
        stopMoblinCloud()
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

    func moblinCloudPlayTipAlert(name: String, message: String, amount: String, currency: String) {
        guard let id = database.moblinCloud.alertsWidgetId,
              let effect = getAlertsEffect(id: id),
              enabledAlertsEffects.contains(where: { $0 === effect })
        else {
            return
        }
        effect.play(alert: .moblinCloudTip(name: name, message: message, amount: amount, currency: currency))
    }

    func moblinCloudTip(name: String, message: String, kind: RemoteControlTipKind, requestId: String) {
        guard !isRemoteControlRequestAlreadyHandled(requestId: requestId) else {
            return
        }
        switch kind {
        case let .message(amount: amount, currency: currency):
            moblinCloudShowTipMessage(name: name, message: message, amount: amount, currency: currency)
        case let .effect(sound: sound):
            moblinCloudTipEffect(name: name, message: message, sound: sound)
        case let .wheelOfLuck(count: count):
            moblinCloudTipWheelOfLuck(name: name, message: message, count: count)
        }
    }

    private func moblinCloudShowTipMessage(name: String, message: String, amount: String, currency: String) {
        var text = String(localized: "Tipped \(amount) \(currency)")
        if !message.isEmpty {
            text += ": \(message)"
        }
        moblinCloudAppendChatMessage(name: name, text: text)
        moblinCloudPlayTipAlert(name: name, message: message, amount: amount, currency: currency)
    }

    private func moblinCloudTipEffect(name: String, message: String, sound: String) {
        guard database.alertsMediaGallery.bundledSounds.contains(where: { $0.name == sound }),
              let url = Bundle.main.url(forResource: "Alerts.bundle/\(sound)", withExtension: "mp3")
        else {
            return
        }
        var text = String(localized: "Played \(sound)")
        if !message.isEmpty {
            text += ": \(message)"
        }
        moblinCloudAppendChatMessage(name: name, text: text)
        moblinCloudEffectPlayer = try? AudioPlayer(contentsOf: url)
        moblinCloudEffectPlayer?.play()
    }

    private func moblinCloudTipWheelOfLuck(name: String, message: String, count: Int) {
        guard let widget = getMoblinCloudWheelOfLuckWidget() else {
            return
        }
        getWheelOfLuckEffect(id: widget.id)?.spin(name: name, message: message, count: min(max(count, 1), 10))
    }

    private func moblinCloudAppendChatMessage(name: String, text: String) {
        appendChatMessage(platform: nil,
                          messageId: nil,
                          displayName: name,
                          user: name,
                          userId: nil,
                          userColor: RgbColor(red: 0x2F, green: 0xF5, blue: 0x2C),
                          userBadges: [],
                          segments: makeChatPostTextSegments(text: text),
                          timestamp: statusOther.digitalClock,
                          timestampTime: .now,
                          isAction: false,
                          isSubscriber: false,
                          isModerator: false,
                          isOwner: false,
                          bits: nil,
                          highlight: ChatHighlight.makeRemoteControlAssistant(),
                          live: true)
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
}

extension MoblinCloud: RemoteControlStreamerDelegate {
    func remoteControlStreamerConnected() {
        model?.makeToast(title: String(localized: "Moblin Cloud connected"))
        model?.updateMoblinCloudStatus()
        model?.moblinCloudSendWheelOfLuck()
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
        guard let model else {
            onCompleted(.error, nil)
            return
        }
        model.remoteControlStreamerMusic(command: command, onCompleted: onCompleted)
    }

    func remoteControlStreamerTip(
        name: String,
        message: String,
        kind: RemoteControlTipKind,
        requestId: String
    ) {
        model?.remoteControlStreamerTip(name: name, message: message, kind: kind, requestId: requestId)
    }
}
