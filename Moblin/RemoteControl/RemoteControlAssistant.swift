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
    var connectionErrorMessage: String = ""
    private var streamerWebSocket: Telegraph.WebSocket?
    private var retryStartTimer = SimpleTimer(queue: .main)
    private weak var delegate: (any RemoteControlAssistantDelegate)?
    private var streamerIdentified: Bool = false
    private var challenge: String = ""
    private var salt: String = ""
    private var encryption: RemoteControlEncryption
    private var twitchEventSub: TwitchEventSub?
    private var twitchChannelId: String?
    private var twitchAccessToken: String?
    private var twitchEventSubNotitications: [String] = []
    private var twitchEventSubNotiticationWaitForResponse: Bool = false

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

    private func handleConnected(webSocket: Telegraph.WebSocket) {
        logger.info("remote-control-assistant: Streamer connected")
        streamerWebSocket = webSocket
        challenge = randomString()
        salt = randomString()
        send(message: .hello(
            apiVersion: remoteControlApiVersion,
            authentication: .init(challenge: challenge, salt: salt)
        ))
        streamerIdentified = false
    }

    private func handleDisconnected(webSocket _: Telegraph.WebSocket, error: Error?) {
        if let error {
            logger.info("remote-control-assistant: Streamer disconnected \(error)")
        } else {
            logger.info("remote-control-assistant: Streamer disconnected")
        }
        streamerWebSocket = nil
        connected = false
        delegate?.remoteControlAssistantDisconnected()
    }

    private func handleStringMessage(webSocket _: Telegraph.WebSocket, message: String) {
        // logger.debug("remote-control-assistant: Got message \(message)")
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
            case let .twitchStart(channelId: channelId, accessToken: accessToken):
                try handleTwitchStart(
                    channelId: channelId,
                    accessToken: accessToken,
                    httpProxy: httpProxy,
                    urlSession: urlSession
                )
            case .twitchStop:
                try handleTwitchStop()
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
            streamerWebSocket?.close(immediately: false)
            streamerWebSocket = nil
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
        guard channelId != twitchChannelId || accessToken != twitchAccessToken || twitchEventSub?
            .isConnected() == false
        else {
            return
        }
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
    }

    private func handleTwitchStop() throws {
        guard streamerIdentified else {
            throw "Streamer not identified"
        }
        twitchChannelId = nil
        twitchAccessToken = nil
        twitchEventSub?.stop()
        twitchEventSubNotitications.removeAll()
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
        logger.info("remote-control-assistant: Twitch not authorized")
    }

    func twitchEventSubNotification(message: String) {
        twitchEventSubNotitications.append(message)
        tryNextTwitchEventSubNotification()
    }
}
