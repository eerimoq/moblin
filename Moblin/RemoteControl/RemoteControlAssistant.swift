import Collections
import CryptoKit
import Foundation
import Telegraph

protocol RemoteControlAssistantDelegate: AnyObject {
    func remoteControlAssistantConnected()
    func remoteControlAssistantDisconnected()
    func remoteControlAssistantPreview(preview: Data)
    func remoteControlAssistantStateChanged(state: RemoteControlState)
    func remoteControlAssistantLog(entry: String)
}

private struct RemoteControlRequestResponse {
    let onSuccess: (RemoteControlResponse?) -> Void
    let onError: (String) -> Void
}

class RemoteControlAssistant: NSObject {
    private let port: UInt16
    private let password: String
    private let httpProxy: HttpProxy?
    private let urlSession: URLSession
    private var connected: Bool = false
    private var nextId: Int = 0
    private var requests: [Int: RemoteControlRequestResponse] = [:]
    private var server: Server
    var connectionErrorMessage = ""
    private var streamerWebSocket: Telegraph.WebSocket?
    private var retryStartTimer = SimpleTimer(queue: .main)
    private weak var delegate: (any RemoteControlAssistantDelegate)?
    private var streamerIdentified = false
    private var challenge = ""
    private var salt = ""
    private var encryption: RemoteControlEncryption
    private var twitchEventSub: TwitchEventSub?
    private var twitchChat: TwitchChatMoblin?
    private var twitchChannelName: String?
    private var twitchChannelId: String?
    private var twitchAccessToken: String?
    private var twitchEventSubNotitications: [String] = []
    private var twitchEventSubNotiticationWaitForResponse = false
    private var chatMessageHistory: Deque<RemoteControlChatMessage> = []
    private var nextChatMessageId = 0
    private let keepAliveTimer = SimpleTimer(queue: .main)
    private var gotPing = false

    init(
        port: UInt16,
        password: String,
        delegate: RemoteControlAssistantDelegate,
        httpProxy: HttpProxy?,
        urlSession: URLSession
    ) {
        self.port = port
        self.password = password
        self.delegate = delegate
        self.httpProxy = httpProxy
        self.urlSession = urlSession
        encryption = RemoteControlEncryption(password: password)
        server = Server()
        super.init()
        server.webSocketConfig.pingInterval = 30
        server.webSocketConfig.readTimeout = 60
        server.webSocketDelegate = self
    }

    func start() {
        stop()
        logger.debug("remote-control-assistant: start")
        startInternal()
    }

    func stop() {
        logger.debug("remote-control-assistant: stop")
        server.stop(immediately: true)
        stopRetryStartTimer()
        twitchEventSub?.stop()
        twitchChat?.stop()
        stopKeepAlive()
    }

    func isConnected() -> Bool {
        return connected
    }

    func getStatus(onSuccess: @escaping (
        RemoteControlStatusGeneral?,
        RemoteControlStatusTopLeft,
        RemoteControlStatusTopRight
    ) -> Void) {
        performRequest(data: .getStatus) { response in
            guard let response else {
                return
            }
            switch response {
            case let .getStatus(general: general, topLeft: topLeft, topRight: topRight):
                onSuccess(general, topLeft, topRight)
            default:
                logger.info("remote-control-assistant: Wrong response to getStatus")
            }
        } onError: { error in
            logger.info("remote-control-assistant: Get status failed with \(error)")
        }
    }

    func getSettings(onSuccess: @escaping (RemoteControlSettings) -> Void) {
        performRequest(data: .getSettings) { response in
            guard let response else {
                return
            }
            switch response {
            case let .getSettings(data: data):
                onSuccess(data)
            default:
                logger.info("remote-control-assistant: Wrong response to getSettings")
            }
        } onError: { error in
            logger.info("remote-control-assistant: Get settings failed with \(error)")
        }
    }

    // periphery:ignore
    func setRecord(on: Bool, onSuccess: @escaping () -> Void) {
        performRequestNoResponseData(data: .setRecord(on: on), onSuccess: onSuccess)
    }

    func setStream(on: Bool, onSuccess: @escaping () -> Void) {
        performRequestNoResponseData(data: .setStream(on: on), onSuccess: onSuccess)
    }

    func setZoom(x: Float, onSuccess: @escaping () -> Void) {
        performRequestNoResponseData(data: .setZoom(x: x), onSuccess: onSuccess)
    }

    func setMute(on: Bool, onSuccess: @escaping () -> Void) {
        performRequestNoResponseData(data: .setMute(on: on), onSuccess: onSuccess)
    }

    // periphery:ignore
    func setTorch(on: Bool, onSuccess: @escaping () -> Void) {
        performRequestNoResponseData(data: .setTorch(on: on), onSuccess: onSuccess)
    }

    func setScene(id: UUID, onSuccess: @escaping () -> Void) {
        performRequestNoResponseData(data: .setScene(id: id), onSuccess: onSuccess)
    }

    func setMic(id: String, onSuccess: @escaping () -> Void) {
        performRequestNoResponseData(data: .setMic(id: id), onSuccess: onSuccess)
    }

    func setBitratePreset(id: UUID, onSuccess: @escaping () -> Void) {
        performRequestNoResponseData(data: .setBitratePreset(id: id), onSuccess: onSuccess)
    }

    func setDebugLogging(on: Bool, onSuccess: @escaping () -> Void) {
        performRequestNoResponseData(data: .setDebugLogging(on: on), onSuccess: onSuccess)
    }

    // periphery:ignore
    func setRemoteSceneSettings(data: RemoteControlRemoteSceneSettings, onSuccess: @escaping () -> Void) {
        performRequestNoResponseData(data: .setRemoteSceneSettings(data: data), onSuccess: onSuccess)
    }

    // periphery:ignore
    func setRemoteSceneData(data: RemoteControlRemoteSceneData, onSuccess: @escaping () -> Void) {
        performRequestNoResponseData(data: .setRemoteSceneData(data: data), onSuccess: onSuccess)
    }

    func reloadBrowserWidgets(onSuccess: @escaping () -> Void) {
        performRequestNoResponseData(data: .reloadBrowserWidgets, onSuccess: onSuccess)
    }

    func setSrtConnectionPrioritiesEnabled(enabled: Bool, onSuccess: @escaping () -> Void) {
        performRequestNoResponseData(
            data: .setSrtConnectionPrioritiesEnabled(enabled: enabled),
            onSuccess: onSuccess
        )
    }

    func setSrtConnectionPriority(id: UUID, priority: Int, enabled: Bool, onSuccess: @escaping () -> Void) {
        performRequestNoResponseData(
            data: .setSrtConnectionPriority(id: id, priority: priority, enabled: enabled),
            onSuccess: onSuccess
        )
    }

    func startPreview() {
        performRequestNoResponseData(data: .startPreview, onSuccess: {})
    }

    func stopPreview() {
        performRequestNoResponseData(data: .stopPreview, onSuccess: {})
    }

    private func tryNextTwitchEventSubNotification() {
        guard !twitchEventSubNotiticationWaitForResponse else {
            return
        }
        guard let message = twitchEventSubNotitications.first else {
            return
        }
        twitchEventSubNotiticationWaitForResponse = true
        performRequestNoResponseData(
            data: .twitchEventSubNotification(message: message),
            onSuccess: {
                self.twitchEventSubNotitications.removeFirst()
                self.twitchEventSubNotiticationWaitForResponse = false
                self.tryNextTwitchEventSubNotification()
            }
        )
    }

    private func getNextChatMessageId() -> Int {
        nextChatMessageId += 1
        return nextChatMessageId
    }

    private func sendChatMessage(message: RemoteControlChatMessage) {
        performRequestNoResponseData(
            data: .chatMessages(history: false, messages: [message]),
            onSuccess: {}
        )
    }

    private func sendChatMessageHistory() {
        performRequestNoResponseData(
            data: .chatMessages(history: true, messages: chatMessageHistory.map { $0 }),
            onSuccess: {}
        )
    }

    private func startInternal() {
        do {
            try server.start(port: Endpoint.Port(port))
            stopRetryStartTimer()
        } catch {
            logger.debug("remote-control-assistant: Failed to start server with error \(error)")
            connectionErrorMessage = error.localizedDescription
            startRetryStartTimer()
        }
    }

    private func startRetryStartTimer() {
        retryStartTimer.startSingleShot(timeout: 5) {
            self.startInternal()
        }
    }

    private func stopRetryStartTimer() {
        retryStartTimer.stop()
    }

    private func startKeepAlive() {
        gotPing = false
        keepAliveTimer.startPeriodic(interval: 60) { [weak self] in
            guard let self else {
                return
            }
            if !gotPing {
                logger.info("remote-control-assistant: Ping not received")
                closeStreamer()
            }
            gotPing = false
        }
    }

    private func stopKeepAlive() {
        keepAliveTimer.stop()
    }

    private func closeStreamer() {
        streamerWebSocket?.close(immediately: false)
        streamerWebSocket = nil
    }

    private func handleConnected(webSocket: Telegraph.WebSocket) {
        logger.debug("remote-control-assistant: Streamer connected")
        streamerWebSocket = webSocket
        challenge = randomString()
        salt = randomString()
        send(message: .hello(
            apiVersion: remoteControlApiVersion,
            authentication: .init(challenge: challenge, salt: salt)
        ))
        streamerIdentified = false
        startKeepAlive()
    }

    private func handleDisconnected(webSocket _: Telegraph.WebSocket, error: Error?) {
        if let error {
            logger.debug("remote-control-assistant: Streamer disconnected \(error)")
        } else {
            logger.debug("remote-control-assistant: Streamer disconnected")
        }
        stopKeepAlive()
        streamerWebSocket = nil
        connected = false
        delegate?.remoteControlAssistantDisconnected()
    }

    private func handleStringMessage(webSocket _: Telegraph.WebSocket, message: String) {
        // logger.debug("remote-control-assistant: Received \(message.prefix(250))")
        do {
            let message = try RemoteControlMessageToAssistant.fromJson(data: message)
            switch message {
            case let .identify(authentication: authentication):
                handleIdentify(authentication: authentication)
            case let .event(data: data):
                try handleEvent(data: data)
            case let .response(id: id, result: result, data: data):
                try handleResponse(id: id, result: result, data: data)
            case let .preview(preview: preview):
                try handlePreview(preview: preview)
            case let .twitchStart(channelName: channelName, channelId: channelId, accessToken: accessToken):
                try handleTwitchStart(
                    channelName: channelName,
                    channelId: channelId,
                    accessToken: accessToken,
                    httpProxy: httpProxy,
                    urlSession: urlSession
                )
            case .ping:
                handlePing()
            }
        } catch {
            logger.debug("remote-control-assistant: Failed to process message with error \(error)")
        }
    }

    private func handleIdentify(authentication: String) {
        if authentication == remoteControlHashPassword(
            challenge: challenge,
            salt: salt,
            password: password
        ) {
            streamerIdentified = true
            connected = true
            delegate?.remoteControlAssistantConnected()
            send(message: .identified(result: .ok))
            twitchEventSubNotiticationWaitForResponse = false
            tryNextTwitchEventSubNotification()
        } else {
            logger.info("remote-control-assistant: Streamer sent wrong password")
            send(message: .identified(result: .wrongPassword))
            closeStreamer()
        }
    }

    private func handleEvent(data: RemoteControlEvent) throws {
        guard streamerIdentified else {
            throw "Streamer not identified"
        }
        switch data {
        case let .state(data: state):
            handleStateEvent(state: state)
        case let .log(entry: entry):
            handleLogEvent(entry: entry)
        case .mediaShareSegmentReceived:
            break
        }
    }

    private func handleResponse(id: Int, result: RemoteControlResult, data: RemoteControlResponse?) throws {
        guard streamerIdentified else {
            throw "Streamer not identified"
        }
        guard let request = requests[id] else {
            logger.debug("remote-control-assistant: Unexpected id in response")
            return
        }
        switch result {
        case .ok:
            request.onSuccess(data)
        case .wrongPassword:
            request.onError("Wrong password")
        case .notIdentified:
            logger.info("remote-control-assistant: Not identified")
        case .alreadyIdentified:
            logger.info("remote-control-assistant: Already identified")
        case .unknownRequest:
            logger.info("remote-control-assistant: Unknown request")
        }
    }

    private func handlePreview(preview: Data) throws {
        guard streamerIdentified else {
            throw "Streamer not identified"
        }
        delegate?.remoteControlAssistantPreview(preview: preview)
    }

    private func handleTwitchStart(
        channelName: String?,
        channelId: String,
        accessToken: String,
        httpProxy: HttpProxy?,
        urlSession: URLSession
    ) throws {
        guard streamerIdentified else {
            throw "Streamer not identified"
        }
        guard let data = Data(base64Encoded: accessToken) else {
            throw "Access token not base64"
        }
        guard let data = encryption.decrypt(data: data) else {
            throw "Access token decryption failed"
        }
        guard let accessToken = String(data: data, encoding: .utf8) else {
            throw "Access token not UTF-8"
        }
        if channelName != nil {
            sendChatMessageHistory()
        }
        guard channelName != twitchChannelName || channelId != twitchChannelId || accessToken != twitchAccessToken ||
            twitchEventSub?
            .isConnected() == false
        else {
            return
        }
        twitchChannelName = channelName
        twitchChannelId = channelId
        twitchAccessToken = accessToken
        twitchEventSub?.stop()
        twitchEventSub = TwitchEventSub(
            remoteControl: false,
            userId: channelId,
            accessToken: accessToken,
            httpProxy: httpProxy,
            urlSession: urlSession,
            delegate: self
        )
        twitchEventSub?.start()
        twitchChat?.stop()
        if let channelName {
            twitchChat = TwitchChatMoblin(delegate: self)
            twitchChat?.start(channelName: channelName,
                              channelId: channelId,
                              settings: SettingsStreamChat(),
                              accessToken: accessToken,
                              httpProxy: httpProxy,
                              urlSession: urlSession)
        }
    }

    private func handlePing() {
        send(message: .pong)
        gotPing = true
    }

    private func handleStateEvent(state: RemoteControlState) {
        delegate?.remoteControlAssistantStateChanged(state: state)
    }

    private func handleLogEvent(entry: String) {
        delegate?.remoteControlAssistantLog(entry: entry)
    }

    private func performRequest(
        data: RemoteControlRequest,
        onSuccess: @escaping (RemoteControlResponse?) -> Void,
        onError: @escaping (String) -> Void
    ) {
        guard connected else {
            onError("Not connected to streamer")
            return
        }
        let id = getNextId()
        requests[id] = RemoteControlRequestResponse(onSuccess: onSuccess, onError: onError)
        send(message: .request(id: id, data: data))
    }

    private func performRequestNoResponseData(data: RemoteControlRequest, onSuccess: @escaping () -> Void) {
        performRequest(data: data) { _ in
            onSuccess()
        } onError: { _ in
        }
    }

    private func getNextId() -> Int {
        nextId += 1
        return nextId
    }

    private func send(message: RemoteControlMessageToStreamer) {
        guard let text = message.toJson() else {
            return
        }
        // logger.debug("remote-control-assistant: Sending \(text)")
        streamerWebSocket?.send(text: text)
    }
}

extension RemoteControlAssistant: ServerWebSocketDelegate {
    func server(
        _: Telegraph.Server,
        webSocketDidConnect webSocket: Telegraph.WebSocket,
        handshake _: Telegraph.HTTPRequest
    ) {
        DispatchQueue.main.async {
            self.handleConnected(webSocket: webSocket)
        }
    }

    func server(_: Telegraph.Server, webSocketDidDisconnect webSocket: Telegraph.WebSocket, error: Error?) {
        DispatchQueue.main.async {
            self.handleDisconnected(webSocket: webSocket, error: error)
        }
    }

    func server(
        _: Telegraph.Server,
        webSocket: Telegraph.WebSocket,
        didReceiveMessage message: Telegraph.WebSocketMessage
    ) {
        guard webSocket.isSame(other: streamerWebSocket) else {
            return
        }
        switch message.payload {
        case let .text(data):
            DispatchQueue.main.async {
                self.handleStringMessage(webSocket: webSocket, message: data)
            }
        default:
            return
        }
    }
}

extension Telegraph.WebSocket {
    func isSame(other: Telegraph.WebSocket?) -> Bool {
        return localEndpoint == other?.localEndpoint && remoteEndpoint == other?.remoteEndpoint
    }
}

extension RemoteControlAssistant: TwitchEventSubDelegate {
    func twitchEventSubChannelAdBreakBegin(event _: TwitchEventSubChannelAdBreakBeginEvent) {}

    func twitchEventSubMakeErrorToast(title _: String) {}

    func twitchEventSubChannelFollow(event _: TwitchEventSubNotificationChannelFollowEvent) {}

    func twitchEventSubChannelSubscribe(event _: TwitchEventSubNotificationChannelSubscribeEvent) {}

    func twitchEventSubChannelSubscriptionGift(
        event _: TwitchEventSubNotificationChannelSubscriptionGiftEvent
    ) {}

    func twitchEventSubChannelSubscriptionMessage(
        event _: TwitchEventSubNotificationChannelSubscriptionMessageEvent
    ) {}

    func twitchEventSubChannelPointsCustomRewardRedemptionAdd(
        event _: TwitchEventSubNotificationChannelPointsCustomRewardRedemptionAddEvent
    ) {}

    func twitchEventSubChannelRaid(event _: TwitchEventSubChannelRaidEvent) {}

    func twitchEventSubChannelCheer(event _: TwitchEventSubChannelCheerEvent) {}

    func twitchEventSubChannelHypeTrainBegin(event _: TwitchEventSubChannelHypeTrainBeginEvent) {}

    func twitchEventSubChannelHypeTrainProgress(event _: TwitchEventSubChannelHypeTrainProgressEvent) {}

    func twitchEventSubChannelHypeTrainEnd(event _: TwitchEventSubChannelHypeTrainEndEvent) {}

    func twitchEventSubUnauthorized() {
        logger.info("remote-control-assistant: twitch-event-sub: Twitch not authorized")
        twitchEventSub?.stop()
        twitchEventSub = nil
    }

    func twitchEventSubNotification(message: String) {
        twitchEventSubNotitications.append(message)
        tryNextTwitchEventSubNotification()
    }
}

extension RemoteControlAssistant: TwitchChatMoblinDelegate {
    func twitchChatMoblinMakeErrorToast(title _: String, subTitle _: String?) {}

    func twitchChatMoblinAppendMessage(
        user: String?,
        userId: String?,
        userColor: RgbColor?,
        userBadges: [URL],
        segments: [ChatPostSegment],
        isAction: Bool,
        isSubscriber: Bool,
        isModerator: Bool,
        bits: String?,
        highlight _: ChatHighlight?
    ) {
        let timestamp = digitalClockFormatter.string(from: Date())
        let message = RemoteControlChatMessage(id: getNextChatMessageId(),
                                               platform: .twitch,
                                               user: user,
                                               userId: userId,
                                               userColor: userColor,
                                               userBadges: userBadges,
                                               segments: segments,
                                               timestamp: timestamp,
                                               isAction: isAction,
                                               isModerator: isModerator,
                                               isSubscriber: isSubscriber,
                                               bits: bits)
        chatMessageHistory.append(message)
        if chatMessageHistory.count > 100 {
            chatMessageHistory.removeFirst()
        }
        sendChatMessage(message: message)
    }
}
