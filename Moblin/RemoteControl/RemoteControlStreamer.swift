import Foundation
import Network

protocol RemoteControlStreamerDelegate: AnyObject {
    func remoteControlStreamerConnected()
    func remoteControlStreamerDisconnected()
    func remoteControlStreamerGetStatus()
        -> (RemoteControlStatusGeneral, RemoteControlStatusTopLeft, RemoteControlStatusTopRight)
    func remoteControlStreamerGetSettings() -> RemoteControlSettings
    func remoteControlStreamerSetScene(id: UUID)
    func remoteControlStreamerSetAutoSceneSwitcher(id: UUID?)
    func remoteControlStreamerSetMic(id: String)
    func remoteControlStreamerSetBitratePreset(id: UUID)
    func remoteControlStreamerSetRecord(on: Bool)
    func remoteControlStreamerSetStream(on: Bool)
    func remoteControlStreamerSetDebugLogging(on: Bool)
    func remoteControlStreamerSetZoom(x: Float)
    func remoteControlStreamerSetZoomPreset(id: UUID)
    func remoteControlStreamerSetMute(on: Bool)
    func remoteControlStreamerSetTorch(on: Bool)
    func remoteControlStreamerReloadBrowserWidgets()
    func remoteControlStreamerSetSrtConnectionPriority(id: UUID, priority: Int, enabled: Bool)
    func remoteControlStreamerSetSrtConnectionPrioritiesEnabled(enabled: Bool)
    func remoteControlStreamerTwitchEventSubNotification(message: String)
    func remoteControlStreamerChatMessages(history: Bool, messages: [RemoteControlChatMessage])
    func remoteControlStreamerStartPreview()
    func remoteControlStreamerStopPreview()
    func remoteControlStreamerSetRemoteSceneSettings(data: RemoteControlRemoteSceneSettings)
    func remoteControlStreamerSetRemoteSceneData(data: RemoteControlRemoteSceneData)
    func remoteControlStreamerInstantReplay()
    func remoteControlStreamerSaveReplay()
    func remoteControlStreamerStartStatus(interval: Int, filter: RemoteControlStartStatusFilter)
    func remoteControlStreamerStopStatus()
}

class RemoteControlStreamer {
    private var clientUrl: URL
    private var password: String
    private weak var delegate: (any RemoteControlStreamerDelegate)?
    private var webSocket: WebSocketClient
    var connectionErrorMessage: String = ""
    private var connected = false
    private var encryption: RemoteControlEncryption
    private let keepAliveTimer = SimpleTimer(queue: .main)
    private var gotPong = true

    init(clientUrl: URL, password: String, delegate: RemoteControlStreamerDelegate) {
        self.clientUrl = clientUrl
        self.password = password
        self.delegate = delegate
        encryption = RemoteControlEncryption(password: password)
        webSocket = .init(url: clientUrl)
    }

    func start() {
        logger.debug("remote-control-streamer: start")
        startInternal()
    }

    func stop() {
        logger.debug("remote-control-streamer: stop")
        stopInternal()
    }

    private func startInternal() {
        stopInternal()
        gotPong = true
        webSocket = .init(url: clientUrl)
        webSocket.delegate = self
        webSocket.start()
    }

    func stopInternal() {
        connected = false
        webSocket.stop()
        stopKeepAlive()
    }

    func isConnected() -> Bool {
        return connected
    }

    func stateChanged(state: RemoteControlState) {
        guard connected else {
            return
        }
        send(message: .event(data: .state(data: state)))
    }

    func log(entry: String) {
        guard connected else {
            return
        }
        send(message: .event(data: .log(entry: entry)))
    }

    func sendPreview(preview: Data) {
        send(message: .preview(preview: preview))
    }

    func sendStatus(
        general: RemoteControlStatusGeneral?,
        topLeft: RemoteControlStatusTopLeft?,
        topRight: RemoteControlStatusTopRight?
    ) {
        send(message: .event(data: .status(general: general, topLeft: topLeft, topRight: topRight)))
    }

    func twitchStart(channelName: String?, channelId: String, accessToken: String) {
        guard connected else {
            return
        }
        guard let accessToken = encryption.encrypt(data: accessToken.utf8Data)?.base64EncodedString() else {
            return
        }
        send(message: .twitchStart(channelName: channelName, channelId: channelId, accessToken: accessToken))
    }

    private func startKeepAlive() {
        keepAliveTimer.startPeriodic(interval: 30) { [weak self] in
            guard let self else {
                return
            }
            if gotPong {
                gotPong = false
                send(message: .ping)
            } else {
                logger.info("remote-control-streamer: Pong not received")
                startInternal()
            }
        }
    }

    private func stopKeepAlive() {
        keepAliveTimer.stop()
    }

    private func send(message: RemoteControlMessageToAssistant) {
        do {
            let message = try message.toJson()
            // logger.debug("remote-control-streamer: Sending message \(message)")
            webSocket.send(string: message)
        } catch {
            logger.info("remote-control-streamer: Encode failed")
        }
    }

    private func handleMessage(message: String) throws {
        do {
            switch try RemoteControlMessageToStreamer.fromJson(data: message) {
            case let .hello(apiVersion: apiVersion, authentication: authentication):
                handleHello(apiVersion: apiVersion, authentication: authentication)
            case let .identified(result: result):
                if !handleIdentified(result: result) {
                    logger.debug("remote-control-streamer: Failed to identify")
                    return
                }
            case let .request(id: id, data: data):
                handleRequest(id: id, data: data)
            case .pong:
                gotPong = true
            }
        } catch {
            logger.info("remote-control-streamer: Decode failed")
            connectionErrorMessage = error.localizedDescription
        }
    }

    private func handleHello(apiVersion _: String, authentication: RemoteControlAuthentication) {
        let hash = remoteControlHashPassword(
            challenge: authentication.challenge,
            salt: authentication.salt,
            password: password
        )
        send(message: .identify(authentication: hash))
    }

    private func handleIdentified(result: RemoteControlResult) -> Bool {
        switch result {
        case .ok:
            connected = true
            delegate?.remoteControlStreamerConnected()
            return true
        case .wrongPassword:
            connectionErrorMessage = "Wrong password"
        default:
            connectionErrorMessage = "Failed to identify"
        }
        return false
    }

    private func handleRequest(id: Int, data: RemoteControlRequest) {
        guard let delegate else {
            return
        }
        switch data {
        case .getStatus:
            let (general, topLeft, topRight) = delegate.remoteControlStreamerGetStatus()
            send(message: .response(
                id: id,
                result: .ok,
                data: .getStatus(general: general, topLeft: topLeft, topRight: topRight)
            ))
        case .getSettings:
            let data = delegate.remoteControlStreamerGetSettings()
            send(message: .response(id: id, result: .ok, data: .getSettings(data: data)))
        case let .setScene(id: sceneId):
            delegate.remoteControlStreamerSetScene(id: sceneId)
            sendEmptyOkResponse(id: id)
        case let .setAutoSceneSwitcher(id: autoSceneSwitcherId):
            delegate.remoteControlStreamerSetAutoSceneSwitcher(id: autoSceneSwitcherId)
            sendEmptyOkResponse(id: id)
        case let .setMic(id: micId):
            delegate.remoteControlStreamerSetMic(id: micId)
            sendEmptyOkResponse(id: id)
        case let .setBitratePreset(id: bitratePresetId):
            delegate.remoteControlStreamerSetBitratePreset(id: bitratePresetId)
            sendEmptyOkResponse(id: id)
        case let .setRecord(on: on):
            delegate.remoteControlStreamerSetRecord(on: on)
            sendEmptyOkResponse(id: id)
        case let .setStream(on: on):
            delegate.remoteControlStreamerSetStream(on: on)
            sendEmptyOkResponse(id: id)
        case let .setZoom(x: x):
            delegate.remoteControlStreamerSetZoom(x: x)
            sendEmptyOkResponse(id: id)
        case let .setZoomPreset(id: presetId):
            delegate.remoteControlStreamerSetZoomPreset(id: presetId)
            sendEmptyOkResponse(id: id)
        case let .setMute(on: on):
            delegate.remoteControlStreamerSetMute(on: on)
            sendEmptyOkResponse(id: id)
        case let .setTorch(on: on):
            delegate.remoteControlStreamerSetTorch(on: on)
            sendEmptyOkResponse(id: id)
        case .reloadBrowserWidgets:
            delegate.remoteControlStreamerReloadBrowserWidgets()
            sendEmptyOkResponse(id: id)
        case let .setSrtConnectionPriority(id: priorityId, priority: priority, enabled: enabled):
            delegate.remoteControlStreamerSetSrtConnectionPriority(id: priorityId, priority: priority, enabled: enabled)
            sendEmptyOkResponse(id: id)
        case let .setSrtConnectionPrioritiesEnabled(enabled: enabled):
            delegate.remoteControlStreamerSetSrtConnectionPrioritiesEnabled(enabled: enabled)
            sendEmptyOkResponse(id: id)
        case let .twitchEventSubNotification(message: message):
            delegate.remoteControlStreamerTwitchEventSubNotification(message: message)
            sendEmptyOkResponse(id: id)
        case let .chatMessages(history: history, messages: messages):
            delegate.remoteControlStreamerChatMessages(history: history, messages: messages)
            sendEmptyOkResponse(id: id)
        case .startPreview:
            delegate.remoteControlStreamerStartPreview()
            sendEmptyOkResponse(id: id)
        case .stopPreview:
            delegate.remoteControlStreamerStopPreview()
            sendEmptyOkResponse(id: id)
        case let .setDebugLogging(on: on):
            delegate.remoteControlStreamerSetDebugLogging(on: on)
            sendEmptyOkResponse(id: id)
        case let .setRemoteSceneSettings(data: data):
            delegate.remoteControlStreamerSetRemoteSceneSettings(data: data)
            sendEmptyOkResponse(id: id)
        case let .setRemoteSceneData(data: data):
            delegate.remoteControlStreamerSetRemoteSceneData(data: data)
            sendEmptyOkResponse(id: id)
        case .instantReplay:
            delegate.remoteControlStreamerInstantReplay()
            sendEmptyOkResponse(id: id)
        case .saveReplay:
            delegate.remoteControlStreamerSaveReplay()
            sendEmptyOkResponse(id: id)
        case let .startStatus(interval: interval, filter: filter):
            delegate.remoteControlStreamerStartStatus(interval: interval, filter: filter)
            sendEmptyOkResponse(id: id)
        case .stopStatus:
            delegate.remoteControlStreamerStopStatus()
            sendEmptyOkResponse(id: id)
        }
    }

    private func sendEmptyOkResponse(id: Int) {
        send(message: .response(id: id, result: .ok, data: nil))
    }
}

extension RemoteControlStreamer: WebSocketClientDelegate {
    func webSocketClientConnected(_: WebSocketClient) {
        logger.info("remote-control-streamer: Connected")
        startKeepAlive()
    }

    func webSocketClientDisconnected(_: WebSocketClient) {
        logger.info("remote-control-streamer: Disconnected")
        stopKeepAlive()
        if connected {
            delegate?.remoteControlStreamerDisconnected()
        }
        connected = false
        connectionErrorMessage = String(localized: "Disconnected")
    }

    func webSocketClientReceiveMessage(_: WebSocketClient, string: String) {
        try? handleMessage(message: string)
    }
}
