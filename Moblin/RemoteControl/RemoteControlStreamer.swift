import Foundation
import Network

protocol RemoteControlStreamerDelegate: AnyObject {
    func connected()
    func disconnected()
    func getStatus(onComplete: @escaping (
        RemoteControlStatusGeneral,
        RemoteControlStatusTopLeft,
        RemoteControlStatusTopRight
    ) -> Void)
    func getSettings(onComplete: @escaping (RemoteControlSettings) -> Void)
    func setScene(id: UUID, onComplete: @escaping () -> Void)
    func setMic(id: String, onComplete: @escaping () -> Void)
    func setBitratePreset(id: UUID, onComplete: @escaping () -> Void)
    func setRecord(on: Bool, onComplete: @escaping () -> Void)
    func setStream(on: Bool, onComplete: @escaping () -> Void)
    func setZoom(x: Float, onComplete: @escaping () -> Void)
    func setMute(on: Bool, onComplete: @escaping () -> Void)
    func setTorch(on: Bool, onComplete: @escaping () -> Void)
    func reloadBrowserWidgets(onComplete: @escaping () -> Void)
    func setSrtConnectionPriority(id: UUID, priority: Int, enabled: Bool, onComplete: @escaping () -> Void)
    func setSrtConnectionPrioritiesEnabled(enabled: Bool, onComplete: @escaping () -> Void)
}

class RemoteControlStreamer {
    private var clientUrl: URL
    private var password: String
    private weak var delegate: (any RemoteControlStreamerDelegate)?
    private var webSocket: WebSocketClient
    var connectionErrorMessage: String = ""
    private var connected = false

    init(clientUrl: URL, password: String, delegate: RemoteControlStreamerDelegate) {
        self.clientUrl = clientUrl
        self.password = password
        self.delegate = delegate
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
            delegate?.connected()
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
            delegate.getStatus { general, topLeft, topRight in
                self.send(message: .response(
                    id: id,
                    result: .ok,
                    data: .getStatus(general: general, topLeft: topLeft, topRight: topRight)
                ))
            }
        case .getSettings:
            delegate.getSettings { data in
                self.send(message: .response(id: id, result: .ok, data: .getSettings(data: data)))
            }
        case let .setScene(id: sceneId):
            delegate.setScene(id: sceneId) {
                self.send(message: .response(id: id, result: .ok, data: nil))
            }
        case let .setMic(id: micId):
            delegate.setMic(id: micId) {
                self.send(message: .response(id: id, result: .ok, data: nil))
            }
        case let .setBitratePreset(id: bitratePresetId):
            delegate.setBitratePreset(id: bitratePresetId) {
                self.send(message: .response(id: id, result: .ok, data: nil))
            }
        case let .setRecord(on: on):
            delegate.setRecord(on: on) {
                self.send(message: .response(id: id, result: .ok, data: nil))
            }
        case let .setStream(on: on):
            delegate.setStream(on: on) {
                self.send(message: .response(id: id, result: .ok, data: nil))
            }
        case let .setZoom(x: x):
            delegate.setZoom(x: x) {
                self.send(message: .response(id: id, result: .ok, data: nil))
            }
        case let .setMute(on: on):
            delegate.setMute(on: on) {
                self.send(message: .response(id: id, result: .ok, data: nil))
            }
        case let .setTorch(on: on):
            delegate.setTorch(on: on) {
                self.send(message: .response(id: id, result: .ok, data: nil))
            }
        case .reloadBrowserWidgets:
            delegate.reloadBrowserWidgets {
                self.send(message: .response(id: id, result: .ok, data: nil))
            }
        case let .setSrtConnectionPriority(id: priorityId, priority: priority, enabled: enabled):
            delegate.setSrtConnectionPriority(id: priorityId, priority: priority, enabled: enabled) {
                self.send(message: .response(id: id, result: .ok, data: nil))
            }
        case let .setSrtConnectionPrioritiesEnabled(enabled: enabled):
            delegate.setSrtConnectionPrioritiesEnabled(enabled: enabled) {
                self.send(message: .response(id: id, result: .ok, data: nil))
            }
        case .newSubscriber:
            break
        case .playMediaShare:
            break
        }
    }
}

extension RemoteControlStreamer: WebSocketClientDelegate {
    func webSocketClientConnected() {}

    func webSocketClientDisconnected() {
        if connected {
            delegate?.disconnected()
        }
        connected = false
        connectionErrorMessage = String(localized: "Disconnected")
    }

    func webSocketClientReceiveMessage(string: String) {
        try? handleMessage(message: string)
    }
}
