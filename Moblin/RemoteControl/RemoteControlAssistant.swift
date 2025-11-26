import Collections
import CryptoKit
import Foundation
import Network

protocol RemoteControlAssistantDelegate: AnyObject {
    func remoteControlAssistantConnected()
    func remoteControlAssistantDisconnected()
    func remoteControlAssistantPreview(preview: Data)
    func remoteControlAssistantStateChanged(state: RemoteControlState)
    func remoteControlAssistantLog(entry: String)
    func remoteControlAssistantStatus(general: RemoteControlStatusGeneral?,
                                      topLeft: RemoteControlStatusTopLeft?,
                                      topRight: RemoteControlStatusTopRight?)
}

private struct RemoteControlRequestResponse {
    let onSuccess: (RemoteControlResponse?) -> Void
    let onError: (String) -> Void
}

class RemoteControlAssistant: NSObject {
    private let port: UInt16
    private let password: String
    private var connected: Bool = false
    private var nextId: Int = 0
    private var requests: [Int: RemoteControlRequestResponse] = [:]
    private var server: NWListener?
    var connectionErrorMessage = ""
    private var streamerWebSocket: NWConnection?
    private var retryStartTimer = SimpleTimer(queue: .main)
    private weak var delegate: (any RemoteControlAssistantDelegate)?
    private var streamerIdentified = false
    private var challenge = ""
    private var salt = ""
    private var encryption: RemoteControlEncryption
    private var twitchEventSub: TwitchEventSub?
    private var twitchChat: TwitchChat?
    private var twitchChannelName: String?
    private var twitchChannelId: String?
    private var twitchAccessToken: String?
    private var twitchEventSubNotitications: [String] = []
    private var twitchEventSubNotiticationWaitForResponse = false
    private var chatMessageHistory: Deque<RemoteControlChatMessage> = []
    private var nextChatMessageId = 0
    private let keepAliveTimer = SimpleTimer(queue: .main)
    private var gotPing = false
    private var pingTimer = SimpleTimer(queue: .main)
    private var pongReceived = true

    init(
        port: UInt16,
        password: String,
        delegate: RemoteControlAssistantDelegate
    ) {
        self.port = port
        self.password = password
        self.delegate = delegate
        encryption = RemoteControlEncryption(password: password)
        super.init()
    }

    func start() {
        stop()
        logger.debug("remote-control-assistant: start")
        startInternal()
    }

    func stop() {
        logger.debug("remote-control-assistant: stop")
        server?.cancel()
        server = nil
        streamerWebSocket?.cancel()
        streamerWebSocket = nil
        server = nil
        stopRetryStartTimer()
        twitchEventSub?.stop()
        twitchChat?.stop()
        stopKeepAlive()
        stopPingTimer()
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

    func setZoomPreset(id: UUID, onSuccess: @escaping () -> Void) {
        performRequestNoResponseData(data: .setZoomPreset(id: id), onSuccess: onSuccess)
    }

    func setMute(on: Bool, onSuccess: @escaping () -> Void) {
        performRequestNoResponseData(data: .setMute(on: on), onSuccess: onSuccess)
    }

    func setTorch(on: Bool, onSuccess: @escaping () -> Void) {
        performRequestNoResponseData(data: .setTorch(on: on), onSuccess: onSuccess)
    }

    func setScene(id: UUID, onSuccess: @escaping () -> Void) {
        performRequestNoResponseData(data: .setScene(id: id), onSuccess: onSuccess)
    }

    func setAutoSceneSwitcher(id: UUID?, onSuccess: @escaping () -> Void) {
        performRequestNoResponseData(data: .setAutoSceneSwitcher(id: id), onSuccess: onSuccess)
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

    func setRemoteSceneSettings(data: RemoteControlRemoteSceneSettings, onSuccess: @escaping () -> Void) {
        performRequestNoResponseData(data: .setRemoteSceneSettings(data: data), onSuccess: onSuccess)
    }

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

    func startStatus() {
        let filter = RemoteControlStartStatusFilter()
        performRequestNoResponseData(data: .startStatus(interval: 1, filter: filter), onSuccess: {})
    }

    func stopStatus() {
        performRequestNoResponseData(data: .stopStatus, onSuccess: {})
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
            let parameters = NWParameters.tcp
            let options = NWProtocolWebSocket.Options()
            options.autoReplyPing = true
            parameters.defaultProtocolStack.applicationProtocols.append(options)
            server = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
            server?.newConnectionHandler = handleNewConnection
            server?.stateUpdateHandler = handleStateUpdate
            server?.start(queue: .main)
        } catch {
            connectionErrorMessage = error.localizedDescription
        }
        startRetryStartTimer()
    }

    private func startRetryStartTimer() {
        retryStartTimer.startSingleShot(timeout: 5) {
            self.startInternal()
        }
    }

    private func stopRetryStartTimer() {
        retryStartTimer.stop()
    }

    private func startPingTimer() {
        pongReceived = true
        pingTimer.startPeriodic(interval: 30, initial: 0) { [weak self] in
            guard let self else {
                return
            }
            if self.pongReceived {
                self.pongReceived = false
                self.streamerWebSocket?.sendWebSocket(data: nil, opcode: .ping)
            } else {
                logger.info("remote-control-assistant: Ping timeout")
                self.closeStreamer()
            }
        }
    }

    private func stopPingTimer() {
        pingTimer.stop()
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
        streamerWebSocket?.cancel()
        streamerWebSocket = nil
    }

    private func handleNewConnection(webSocket: NWConnection) {
        logger.debug("remote-control-assistant: Streamer connected")
        streamerWebSocket?.cancel()
        streamerWebSocket = webSocket
        webSocket.start(queue: .main)
        receivePacket(webSocket: webSocket)
        challenge = randomString()
        salt = randomString()
        send(message: .hello(
            apiVersion: remoteControlApiVersion,
            authentication: .init(challenge: challenge, salt: salt)
        ))
        streamerIdentified = false
        startKeepAlive()
        startPingTimer()
    }

    private func handleStateUpdate(_ newState: NWListener.State) {
        switch newState {
        case .ready:
            stopRetryStartTimer()
        default:
            break
        }
    }

    private func handleDisconnected(webSocket _: NWConnection) {
        logger.debug("remote-control-assistant: Streamer disconnected")
        stopKeepAlive()
        stopPingTimer()
        streamerWebSocket?.cancel()
        streamerWebSocket = nil
        connected = false
        delegate?.remoteControlAssistantDisconnected()
    }

    private func receivePacket(webSocket: NWConnection) {
        webSocket.receiveMessage { data, context, _, _ in
            switch context?.webSocketOperation() {
            case .text:
                if let data, !data.isEmpty {
                    self.handleMessage(webSocket: webSocket, packet: data)
                    self.receivePacket(webSocket: webSocket)
                } else {
                    self.handleDisconnected(webSocket: webSocket)
                }
            case .ping:
                webSocket.sendWebSocket(data: data, opcode: .pong)
                self.receivePacket(webSocket: webSocket)
            case .pong:
                self.pongReceived = true
                self.receivePacket(webSocket: webSocket)
            default:
                self.handleDisconnected(webSocket: webSocket)
            }
        }
    }

    private func handleMessage(webSocket: NWConnection, packet: Data) {
        if let text = String(bytes: packet, encoding: .utf8) {
            handleStringMessage(webSocket: webSocket, message: text)
        }
    }

    private func handleStringMessage(webSocket _: NWConnection, message: String) {
        // logger.info("remote-control-assistant: Received \(message.prefix(250))")
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
                    accessToken: accessToken
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
            send(message: .identified(result: .ok))
            delegate?.remoteControlAssistantConnected()
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
        case let .status(general: general, topLeft: topLeft, topRight: topRight):
            handleStatusEvent(general: general, topLeft: topLeft, topRight: topRight)
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
        accessToken: String
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
            delegate: self
        )
        twitchEventSub?.start()
        twitchChat?.stop()
        if let channelName {
            twitchChat = TwitchChat(delegate: self)
            twitchChat?.start(channelName: channelName,
                              channelId: channelId,
                              settings: SettingsStreamChat(),
                              accessToken: accessToken)
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

    private func handleStatusEvent(general: RemoteControlStatusGeneral?,
                                   topLeft: RemoteControlStatusTopLeft?,
                                   topRight: RemoteControlStatusTopRight?)
    {
        delegate?.remoteControlAssistantStatus(general: general, topLeft: topLeft, topRight: topRight)
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
        streamerWebSocket?.sendWebSocket(data: text.data(using: .utf8), opcode: .text)
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

extension RemoteControlAssistant: TwitchChatDelegate {
    func twitchChatMakeErrorToast(title _: String, subTitle _: String?) {}

    func twitchChatAppendMessage(
        messageId: String?,
        displayName: String,
        user: String,
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
                                               messageId: messageId,
                                               displayName: displayName,
                                               user: user,
                                               userId: userId,
                                               userColor: userColor,
                                               userBadges: userBadges,
                                               segments: segments,
                                               timestamp: timestamp,
                                               isAction: isAction,
                                               isModerator: isModerator,
                                               isSubscriber: isSubscriber,
                                               isOwner: false,
                                               bits: bits)
        chatMessageHistory.append(message)
        if chatMessageHistory.count > 100 {
            chatMessageHistory.removeFirst()
        }
        sendChatMessage(message: message)
    }

    func twitchChatDeleteMessage(messageId _: String) {}

    func twitchChatDeleteUser(userId _: String) {}
}
