import Foundation
import Network

protocol RemoteControlStreamerDelegate: AnyObject {
    func remoteControlStreamerConnected()
    func remoteControlStreamerDisconnected()
    func remoteControlStreamerGetStatus(onComplete: @escaping (
        RemoteControlStatusGeneral,
        RemoteControlStatusTopLeft,
        RemoteControlStatusTopRight
    ) -> Void)
    func remoteControlStreamerGetSettings(onComplete: @escaping (RemoteControlSettings) -> Void)
    func remoteControlStreamerSetScene(id: UUID, onComplete: @escaping () -> Void)
    func remoteControlStreamerSetMic(id: String, onComplete: @escaping () -> Void)
    func remoteControlStreamerSetBitratePreset(id: UUID, onComplete: @escaping () -> Void)
    func remoteControlStreamerSetRecord(on: Bool, onComplete: @escaping () -> Void)
    func remoteControlStreamerSetStream(on: Bool, onComplete: @escaping () -> Void)
    func remoteControlStreamerSetDebugLogging(on: Bool, onComplete: @escaping () -> Void)
    func remoteControlStreamerSetZoom(x: Float, onComplete: @escaping () -> Void)
    func remoteControlStreamerSetMute(on: Bool, onComplete: @escaping () -> Void)
    func remoteControlStreamerSetTorch(on: Bool, onComplete: @escaping () -> Void)
    func remoteControlStreamerReloadBrowserWidgets(onComplete: @escaping () -> Void)
    func remoteControlStreamerSetSrtConnectionPriority(
        id: UUID,
        priority: Int,
        enabled: Bool,
        onComplete: @escaping () -> Void
    )
    func remoteControlStreamerSetSrtConnectionPrioritiesEnabled(
        enabled: Bool,
        onComplete: @escaping () -> Void
    )
    func remoteControlStreamerTwitchEventSubNotification(message: String)
    func remoteControlStreamerChatMessages(history: Bool, messages: [RemoteControlChatMessage])
    func remoteControlStreamerStartPreview(onComplete: @escaping () -> Void)
    func remoteControlStreamerStopPreview(onComplete: @escaping () -> Void)
}

class RemoteControlStreamer {
    private var clientUrl: URL
    private var password: String
    private weak var delegate: (any RemoteControlStreamerDelegate)?
    private var webSocket: WebSocketClient
    var connectionErrorMessage: String = ""
    private var connected = false
    private var encryption: RemoteControlEncryption

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
        webSocket = .init(url: clientUrl)
        webSocket.delegate = self
        webSocket.start()
    }

    func stopInternal() {
        connected = false
        webSocket.stop()
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

    func twitchStart(channelName: String?, channelId: String, accessToken: String) {
        guard connected else {
            return
        }
        guard let accessToken = encryption.encrypt(data: accessToken.utf8Data)?.base64EncodedString() else {
            return
        }
        send(message: .twitchStart(channelName: channelName, channelId: channelId, accessToken: accessToken))
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
            delegate.remoteControlStreamerGetStatus { general, topLeft, topRight in
                self.send(message: .response(
                    id: id,
                    result: .ok,
                    data: .getStatus(general: general, topLeft: topLeft, topRight: topRight)
                ))
            }
        case .getSettings:
            delegate.remoteControlStreamerGetSettings { data in
                self.send(message: .response(id: id, result: .ok, data: .getSettings(data: data)))
            }
        case let .setScene(id: sceneId):
            delegate.remoteControlStreamerSetScene(id: sceneId) {
                self.send(message: .response(id: id, result: .ok, data: nil))
            }
        case let .setMic(id: micId):
            delegate.remoteControlStreamerSetMic(id: micId) {
                self.send(message: .response(id: id, result: .ok, data: nil))
            }
        case let .setBitratePreset(id: bitratePresetId):
            delegate.remoteControlStreamerSetBitratePreset(id: bitratePresetId) {
                self.send(message: .response(id: id, result: .ok, data: nil))
            }
        case let .setRecord(on: on):
            delegate.remoteControlStreamerSetRecord(on: on) {
                self.send(message: .response(id: id, result: .ok, data: nil))
            }
        case let .setStream(on: on):
            delegate.remoteControlStreamerSetStream(on: on) {
                self.send(message: .response(id: id, result: .ok, data: nil))
            }
        case let .setZoom(x: x):
            delegate.remoteControlStreamerSetZoom(x: x) {
                self.send(message: .response(id: id, result: .ok, data: nil))
            }
        case let .setMute(on: on):
            delegate.remoteControlStreamerSetMute(on: on) {
                self.send(message: .response(id: id, result: .ok, data: nil))
            }
        case let .setTorch(on: on):
            delegate.remoteControlStreamerSetTorch(on: on) {
                self.send(message: .response(id: id, result: .ok, data: nil))
            }
        case .reloadBrowserWidgets:
            delegate.remoteControlStreamerReloadBrowserWidgets {
                self.send(message: .response(id: id, result: .ok, data: nil))
            }
        case let .setSrtConnectionPriority(id: priorityId, priority: priority, enabled: enabled):
            delegate.remoteControlStreamerSetSrtConnectionPriority(
                id: priorityId,
                priority: priority,
                enabled: enabled
            ) {
                self.send(message: .response(id: id, result: .ok, data: nil))
            }
        case let .setSrtConnectionPrioritiesEnabled(enabled: enabled):
            delegate.remoteControlStreamerSetSrtConnectionPrioritiesEnabled(enabled: enabled) {
                self.send(message: .response(id: id, result: .ok, data: nil))
            }
        case let .twitchEventSubNotification(message: message):
            delegate.remoteControlStreamerTwitchEventSubNotification(message: message)
            send(message: .response(id: id, result: .ok, data: nil))
        case let .chatMessages(history: history, messages: messages):
            delegate.remoteControlStreamerChatMessages(history: history, messages: messages)
            send(message: .response(id: id, result: .ok, data: nil))
        case .startPreview:
            delegate.remoteControlStreamerStartPreview {
                self.send(message: .response(id: id, result: .ok, data: nil))
            }
        case .stopPreview:
            delegate.remoteControlStreamerStopPreview {
                self.send(message: .response(id: id, result: .ok, data: nil))
            }
        case let .setDebugLogging(on: on):
            delegate.remoteControlStreamerSetDebugLogging(on: on) {
                self.send(message: .response(id: id, result: .ok, data: nil))
            }
        }
    }
}

extension RemoteControlStreamer: WebSocketClientDelegate {
    func webSocketClientConnected(_: WebSocketClient) {
        logger.info("remote-control-streamer: Connected")
    }

    func webSocketClientDisconnected(_: WebSocketClient) {
        logger.info("remote-control-streamer: Disconnected")
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
