import CryptoKit
import DeviceCheck
import Foundation

let moblinWebsiteApiUrl = Bundle.main.object(forInfoDictionaryKey: "MoblinWebsiteApiUrl") as! String
private let moblinCloudApiUrl = Bundle.main.object(forInfoDictionaryKey: "MoblinCloudApiUrl") as! String
private let liveUrl = URL(string: "\(moblinWebsiteApiUrl)/streamers/live")!
private let challengeUrl = URL(string: "\(moblinWebsiteApiUrl)/streamers/live/challenge")!
private let appAttestStorage = SimpleStringStorage(key: "moblinWebsiteAppAttest")

private struct MoblinCloudChannel: Encodable {
    let platform: String
    let name: String
}

private struct MoblinCloudLive: Encodable {
    let channels: [MoblinCloudChannel]
    let challenge: String
    let keyId: String
    let attestation: String
    let attestationChallenge: String
}

private struct MoblinCloudChallenge: Decodable {
    let challenge: String
}

private struct MoblinCloudAppAttest: Codable {
    let keyId: String
    let challenge: Data
    var attestation: Data?

    func attestationBase64() -> String {
        attestation!.base64EncodedString()
    }

    func challengeBase64() -> String {
        challenge.base64EncodedString()
    }
}

private enum MoblinCloudError: Error {
    case notSupported
    case keyRejected(String)
    case badResponse(String)
}

private func describe(_ response: URLResponse, _ data: Data) -> String {
    guard let response = response.http else {
        return "not HTTP"
    }
    return "\(response.statusCode) \(String(bytes: data, encoding: .utf8) ?? "")"
}

private func loadAppAttest() -> MoblinCloudAppAttest? {
    try? JSONDecoder().decode(MoblinCloudAppAttest.self, from: Data(appAttestStorage.get().utf8))
}

private func storeAppAttest(_ appAttest: MoblinCloudAppAttest?) {
    guard let appAttest, let data = try? JSONEncoder().encode(appAttest) else {
        appAttestStorage.set("")
        return
    }
    appAttestStorage.set(String(bytes: data, encoding: .utf8) ?? "")
}

private func attestedKey() async throws -> MoblinCloudAppAttest {
    let service = DCAppAttestService.shared
    var appAttest: MoblinCloudAppAttest
    if let stored = loadAppAttest() {
        if stored.attestation != nil {
            return stored
        }
        appAttest = stored
    } else {
        let keyId = try await service.generateKey()
        let challenge = Data((0 ..< 32).map { _ in UInt8.random(in: .min ... .max) })
        appAttest = MoblinCloudAppAttest(keyId: keyId, challenge: challenge, attestation: nil)
        storeAppAttest(appAttest)
    }
    do {
        let clientDataHash = Data(SHA256.hash(data: appAttest.challenge))
        appAttest.attestation = try await service.attestKey(appAttest.keyId, clientDataHash: clientDataHash)
    } catch let error as DCError where error.code == .serverUnavailable {
        throw error
    } catch {
        storeAppAttest(nil)
        throw error
    }
    storeAppAttest(appAttest)
    return appAttest
}

private func withAttestedKey<T>(_ body: (MoblinCloudAppAttest) async throws -> T) async throws -> T {
    guard DCAppAttestService.shared.isSupported else {
        throw MoblinCloudError.notSupported
    }
    let attestedBefore = loadAppAttest()?.attestation != nil
    do {
        return try await body(attestedKey())
    } catch let MoblinCloudError.keyRejected(reason) where attestedBefore {
        logger.info("moblin-website: Key rejected (\(reason)), attesting a new one")
        storeAppAttest(nil)
        return try await body(attestedKey())
    }
}

private func generateAssertion(appAttest: MoblinCloudAppAttest, clientData: Data) async throws -> Data {
    do {
        return try await DCAppAttestService.shared.generateAssertion(
            appAttest.keyId,
            clientDataHash: Data(SHA256.hash(data: clientData))
        )
    } catch {
        throw MoblinCloudError.keyRejected("assertion: \(error)")
    }
}

private func fetchChallenge() async throws -> String {
    var request = URLRequest(url: challengeUrl, timeoutInterval: 30)
    request.httpMethod = "POST"
    let (data, response) = try await httpUrlSession().data(for: request)
    guard response.http?.isSuccessful == true else {
        throw MoblinCloudError.badResponse("challenge: \(describe(response, data))")
    }
    return try JSONDecoder().decode(MoblinCloudChallenge.self, from: data).challenge
}

private func postLive(channels: [MoblinCloudChannel], appAttest: MoblinCloudAppAttest) async throws {
    let challenge = try await fetchChallenge()
    let live = MoblinCloudLive(
        channels: channels,
        challenge: challenge,
        keyId: appAttest.keyId,
        attestation: appAttest.attestationBase64(),
        attestationChallenge: appAttest.challengeBase64()
    )
    let body = try JSONEncoder().encode(live)
    let assertion = try await generateAssertion(appAttest: appAttest, clientData: body)
    var request = URLRequest(url: liveUrl, timeoutInterval: 30)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(assertion.base64EncodedString(), forHTTPHeaderField: "Moblin-Assertion")
    request.httpBody = body
    let (data, response) = try await httpUrlSession().data(for: request)
    if response.http?.isUnauthorized == true {
        throw MoblinCloudError.keyRejected("live: \(describe(response, data))")
    }
    guard response.http?.isSuccessful == true else {
        throw MoblinCloudError.badResponse("live: \(describe(response, data))")
    }
}

private func makeAppAttest(challenge: Data,
                           appAttest: MoblinCloudAppAttest) async throws -> RemoteControlAppAttest
{
    let assertion = try await generateAssertion(appAttest: appAttest, clientData: challenge)
    return RemoteControlAppAttest(
        keyId: appAttest.keyId,
        attestation: appAttest.attestationBase64(),
        attestationChallenge: appAttest.challengeBase64(),
        assertion: assertion.base64EncodedString()
    )
}

private func makeMoblinCloudAppAttest(challenge: Data) async -> RemoteControlAppAttest? {
    do {
        return try await withAttestedKey { try await makeAppAttest(challenge: challenge, appAttest: $0) }
    } catch {
        logger.info("moblin-website: App Attest failed: \(error)")
        return nil
    }
}

private func sendLive(channels: [MoblinCloudChannel]) async {
    do {
        try await withAttestedKey { try await postLive(channels: channels, appAttest: $0) }
    } catch {
        logger.info("moblin-website: Failed to send live: \(error)")
    }
}

private func makeMoblinCloudUrl(key: String) -> URL? {
    guard var components = URLComponents(string: moblinCloudApiUrl) else {
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
    func sendLiveToMoblinWebsite(onCompleted: (@MainActor () -> Void)? = nil) {
        guard !isMac(), stream.goLiveNotificationMoblinWebsite else {
            onCompleted?()
            return
        }
        let stream = stream
        Task {
            defer {
                onCompleted?()
            }
            var channels: [MoblinCloudChannel] = []
            if stream.twitchLoggedIn, let name = await fetchTwitchChannelName(stream: stream), !name.isEmpty {
                channels.append(.init(platform: "twitch", name: name))
            }
            if stream.isYouTubeAuthorized(), let name = await fetchYouTubeHandle(stream: stream),
               !name.isEmpty
            {
                channels.append(.init(platform: "youtube", name: name))
            }
            if stream.kickLoggedIn, let name = await fetchKickChannelName(stream: stream), !name.isEmpty {
                channels.append(.init(platform: "kick", name: name))
            }
            guard !channels.isEmpty else {
                return
            }
            await sendLive(channels: channels)
        }
    }

    func stopMoblinCloud() {
        moblinCloud?.stop()
        moblinCloud = nil
        setLowFpsImage()
    }

    func isMoblinCloudPreviewActive() -> Bool {
        moblinCloud?.isRequestingPreview() ?? false
    }

    func sendPreviewToMoblinCloud(preview: Data) {
        moblinCloud?.sendPreview(preview: preview)
    }

    func reloadMoblinCloud() {
        stopMoblinCloud()
        let settings = database.moblinCloud
        let key = settings.key.trim()
        guard !isMac(), settings.enabled, !key.isEmpty, let url = makeMoblinCloudUrl(key: key) else {
            updateMoblinCloudStatus()
            return
        }
        moblinCloud = MoblinCloud(model: self, url: url, streamerId: getRemoteControlStreamerId())
        moblinCloud?.start()
        updateMoblinCloudStatus()
    }

    func isShowingStatusMoblinCloud() -> Bool {
        database.show.moblinCloud && database.moblinCloud.enabled && !isMac()
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

    func moblinCloudSendIcon() {
        moblinCloud?.sendIcon(id: database.iconImage)
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
        moblinCloudTipEffects.append((name, text, url))
        moblinCloudTryNextEffect()
    }

    private func moblinCloudTryNextEffect() {
        guard moblinCloudTipEffectPlayer == nil,
              let (name, text, url) = moblinCloudTipEffects.popFirst()
        else {
            return
        }
        moblinCloudAppendChatMessage(name: name, text: text)
        moblinCloudTipEffectPlayer = try? AudioPlayer(contentsOf: url)
        moblinCloudTipEffectPlayer?.play()
        let timeUntilNextEffect = (moblinCloudTipEffectPlayer?.duration() ?? 0) + 3
        moblinCloudTipEffectTimer.startSingleShot(timeout: timeUntilNextEffect) {
            self.moblinCloudTipEffectPlayer = nil
            self.moblinCloudTryNextEffect()
        }
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

    private func fetchTwitchChannelName(stream: SettingsStream) async -> String? {
        await withCheckedContinuation { continuation in
            createTwitchApi(stream: stream).getUserInfo { info in
                continuation.resume(returning: info?.login.trim())
            }
        }
    }

    private func fetchYouTubeHandle(stream: SettingsStream) async -> String? {
        await withCheckedContinuation { continuation in
            getYouTubeApi(stream: stream) { youTubeApi in
                guard let youTubeApi else {
                    continuation.resume(returning: nil)
                    return
                }
                youTubeApi.listChannels {
                    switch $0 {
                    case let .success(response):
                        let handle = response.items.first?.snippet.customUrl?.trim().trimmingPrefix("@")
                        continuation.resume(returning: handle.map { String($0) })
                    case .authError, .error:
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }

    private func fetchKickChannelName(stream: SettingsStream) async -> String? {
        await withCheckedContinuation { continuation in
            createKickApi(stream: stream).getUser { user in
                continuation.resume(returning: user?.username.trim())
            }
        }
    }
}

@MainActor
class MoblinCloud {
    private weak var model: Model?
    private var streamer: RemoteControlStreamer?
    private var requestingStatus = false
    private var statusFilter: RemoteControlStartStatusFilter?
    private var requestingPreview = false

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

    func sendIcon(id: String) {
        streamer?.sendIcon(id: id)
    }

    func stateChanged(state: RemoteControlAssistantStreamerState) {
        guard requestingStatus else {
            return
        }
        streamer?.stateChanged(state: state)
    }

    func isRequestingPreview() -> Bool {
        requestingPreview
    }

    func sendPreview(preview: Data) {
        guard requestingPreview, let streamer, streamer.isConnected() else {
            return
        }
        streamer.sendPreview(preview: preview)
    }

    func sendPeriodicStatus() {
        guard requestingStatus, let streamer, streamer.isConnected(), let model else {
            return
        }
        let (general, topLeft, topRight) = model.createRemoteControlStatus(filter: statusFilter)
        streamer.sendStatus(general: general, topLeft: topLeft, topRight: topRight)
    }

    private func setRequestingStatus(_ on: Bool, filter: RemoteControlStartStatusFilter? = nil) {
        requestingStatus = on
        statusFilter = filter
    }

    private func setRequestingPreview(_ on: Bool) {
        requestingPreview = on
        model?.setLowFpsImage()
    }
}

extension MoblinCloud: RemoteControlStreamerDelegate {
    func remoteControlStreamerAppAttest(
        challenge: Data,
        onCompleted: @escaping (RemoteControlAppAttest?) -> Void
    ) {
        Task {
            await onCompleted(makeMoblinCloudAppAttest(challenge: challenge))
        }
    }

    func remoteControlStreamerConnected() {
        setRequestingStatus(false)
        setRequestingPreview(false)
        model?.updateMoblinCloudStatus()
        model?.moblinCloudSendWheelOfLuck()
        model?.moblinCloudSendIcon()
    }

    func remoteControlStreamerDisconnected() {
        setRequestingStatus(false)
        setRequestingPreview(false)
        model?.updateMoblinCloudStatus()
    }

    func remoteControlStreamerWrongPassword() {}

    func remoteControlStreamerGetStatus()
        -> (RemoteControlStatusGeneral, RemoteControlStatusTopLeft, RemoteControlStatusTopRight)
    {
        model?.remoteControlGetStatus() ?? (.init(), .init(), .init())
    }

    func remoteControlStreamerGetSettings() -> RemoteControlSettings {
        model?.remoteControlGetSettings() ?? RemoteControlSettings(
            streams: [],
            scenes: [],
            autoSceneSwitchers: nil,
            bitratePresets: [],
            mics: [],
            srt: .init(connectionPrioritiesEnabled: false, connectionPriorities: [])
        )
    }

    func remoteControlStreamerSetStream(id: UUID) {
        model?.remoteControlSetStream(id: id)
    }

    func remoteControlStreamerSetScene(id: UUID) {
        model?.selectScene(id: id)
    }

    func remoteControlStreamerSetAutoSceneSwitcher(id: UUID?) {
        model?.setAutoSceneSwitcher(id: id)
    }

    func remoteControlStreamerSetMic(id: String) {
        model?.manualSelectMicById(id: id)
    }

    func remoteControlStreamerSetTalkbackMic(id _: String) {}

    func remoteControlStreamerSetBitratePreset(id: UUID) {
        model?.remoteControlSetBitratePreset(id: id)
    }

    func remoteControlStreamerSetRecord(on: Bool) {
        model?.remoteControlSetRecord(on: on)
    }

    func remoteControlStreamerSetLive(on: Bool) {
        model?.remoteControlSetLive(on: on)
    }

    func remoteControlStreamerSetPreviewStream(on: Bool) {
        model?.remoteControlSetPreviewStream(on: on)
    }

    func remoteControlStreamerSetDebugLogging(on _: Bool) {}

    func remoteControlStreamerSetZoom(x: Float) {
        model?.remoteControlSetZoom(x: x)
    }

    func remoteControlStreamerSetZoomPreset(id: UUID) {
        model?.setZoomPreset(id: id)
    }

    func remoteControlStreamerSetMute(on: Bool) {
        model?.setMuteOn(value: on)
    }

    func remoteControlStreamerSetStealthMode(on: Bool) {
        model?.setStealthMode(on: on)
    }

    func remoteControlStreamerSetTorch(on: Bool) {
        model?.remoteControlSetTorch(on: on)
    }

    func remoteControlStreamerReloadBrowserWidgets() {
        model?.reloadBrowserWidgets()
    }

    func remoteControlStreamerSetSrtConnectionPriority(id: UUID, priority: Int, enabled: Bool) {
        model?.remoteControlSetSrtConnectionPriority(id: id, priority: priority, enabled: enabled)
    }

    func remoteControlStreamerSetSrtConnectionPrioritiesEnabled(enabled: Bool) {
        model?.remoteControlSetSrtConnectionPrioritiesEnabled(enabled: enabled)
    }

    func remoteControlStreamerTwitchEventSubNotification(message _: String) {}

    func remoteControlStreamerChatMessages(history _: Bool, messages _: [RemoteControlChatMessage]) {}

    func remoteControlStreamerStartPreview() {
        setRequestingPreview(true)
    }

    func remoteControlStreamerStopPreview() {
        setRequestingPreview(false)
    }

    func remoteControlStreamerSetRemoteSceneSettings(data _: RemoteControlRemoteSceneSettings) {}

    func remoteControlStreamerSetRemoteSceneData(data _: RemoteControlRemoteSceneData) {}

    func remoteControlStreamerInstantReplay() {
        model?.instantReplay()
    }

    func remoteControlStreamerSaveReplay() {
        _ = model?.saveReplay()
    }

    func remoteControlStreamerStartStatus(interval _: Int, filter: RemoteControlStartStatusFilter) {
        setRequestingStatus(true, filter: filter)
        if let model {
            streamer?.stateChanged(state: model.createRemoteControlStateChanged())
        }
        sendPeriodicStatus()
    }

    func remoteControlStreamerStopStatus() {
        setRequestingStatus(false)
    }

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

    func remoteControlStreamerSetFilter(filter: RemoteControlFilter, on: Bool) {
        model?.remoteControlSetFilter(filter: filter, on: on)
    }

    func remoteControlStreamerTriggerReaction(reaction _: RemoteControlReaction) {}

    func remoteControlStreamerMoveToGimbalPreset(id _: UUID) {}

    func remoteControlStreamerSetGimbalTracking(on: Bool) {
        model?.setGimbalTracking(on: on)
    }

    func remoteControlStreamerSetGimbalMovement(x _: Float, y _: Float) {}

    func remoteControlStreamerAnimateGimbal(motion _: SettingsGimbalMotion) {}

    func remoteControlStreamerSaveGimbalPreset() {}

    func remoteControlStreamerImportSettings(settings _: Data, onCompleted: @escaping (Bool) -> Void) {
        onCompleted(false)
    }

    func remoteControlStreamerStartStats(filter _: RemoteControlStartStatsFilter?) {}

    func remoteControlStreamerStopStats() {}

    func remoteControlStreamerStartMacro(id: UUID) {
        model?.startMacro(id: id)
    }

    func remoteControlStreamerStopMacro(id: UUID) {
        model?.stopMacro(id: id)
    }

    func remoteControlStreamerSendMessage(text: String) {
        model?.remoteControlSendMessage(text: text)
    }

    func remoteControlStreamerMusic(command: RemoteControlMusicCommand,
                                    onCompleted: @escaping (RemoteControlResult, RemoteControlResponse?)
                                        -> Void)
    {
        guard let model else {
            onCompleted(.error, nil)
            return
        }
        model.remoteControlMusic(command: command, onCompleted: onCompleted)
    }

    func remoteControlStreamerTip(
        name: String,
        message: String,
        kind: RemoteControlTipKind,
        requestId: String
    ) {
        model?.moblinCloudTip(name: name, message: message, kind: kind, requestId: requestId)
    }
}
