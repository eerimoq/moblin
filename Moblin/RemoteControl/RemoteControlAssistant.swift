import CryptoKit
import Foundation
import Telegraph

protocol RemoteControlAssistantDelegate: AnyObject {
    func assistantConnected()
    func assistantDisconnected()
    func assistantStateChanged(state: RemoteControlState)
}

private struct RemoteControlRequestResponse {
    let onSuccess: (RemoteControlResponse?) -> Void
    let onError: (String) -> Void
}

private func randomString() -> String {
    return Data.random(length: 64).base64EncodedString()
}

class RemoteControlAssistant {
    private let address: String
    private let port: UInt16
    private let password: String
    private var connected: Bool = false
    private var nextId: Int = 0
    private var requests: [Int: RemoteControlRequestResponse] = [:]
    private var server: Server
    var connectionErrorMessage: String = ""
    private var streamerWebSocket: Telegraph.WebSocket?
    private var retryStartTimer: DispatchSourceTimer?
    private weak var delegate: (any RemoteControlAssistantDelegate)?
    private var streamerIdentified: Bool = false
    private var challenge: String = ""
    private var salt: String = ""

    init(
        address: String,
        port: UInt16,
        password: String,
        delegate: RemoteControlAssistantDelegate
    ) {
        self.address = address
        self.port = port
        self.password = password
        self.delegate = delegate
        server = Server()
        server.webSocketConfig.pingInterval = 30
        server.webSocketConfig.readTimeout = 60
        server.webSocketDelegate = self
    }

    func start() {
        stop()
        logger.info("remote-control-assistant: start")
        startInternal()
    }

    func stop() {
        logger.info("remote-control-assistant: stop")
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

    func setTorch(on: Bool, onSuccess: @escaping () -> Void) {
        performRequestNoResponseData(data: .setTorch(on: on), onSuccess: onSuccess)
    }

    func setScene(id: UUID, onSuccess: @escaping () -> Void) {
        performRequestNoResponseData(data: .setScene(id: id), onSuccess: onSuccess)
    }

    func setBitratePreset(id: UUID, onSuccess: @escaping () -> Void) {
        performRequestNoResponseData(data: .setBitratePreset(id: id), onSuccess: onSuccess)
    }

    private func startInternal() {
        do {
            try server.start(port: Endpoint.Port(port), interface: address)
            stopRetryStartTimer()
        } catch {
            logger.debug("remote-control-assistant: Failed to start server with error \(error)")
            startRetryStartTimer()
        }
    }

    private func startRetryStartTimer() {
        retryStartTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        retryStartTimer!.schedule(deadline: .now() + 5)
        retryStartTimer!.setEventHandler {
            self.startInternal()
        }
        retryStartTimer!.activate()
    }

    private func stopRetryStartTimer() {
        retryStartTimer?.cancel()
        retryStartTimer = nil
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
        delegate?.assistantDisconnected()
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
            }
        } catch {
            logger.info("remote-control-assistant: Failed to process message with error \(error)")
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
            delegate?.assistantConnected()
        }
    }

    private func handleEvent(data: RemoteControlEvent) throws {
        guard streamerIdentified else {
            throw "Streamer not identified"
        }
        switch data {
        case let .state(data: state):
            handleStateEvent(state: state)
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

    private func handleStateEvent(state: RemoteControlState) {
        delegate?.assistantStateChanged(state: state)
    }

    private func performRequest(
        data: RemoteControlRequest,
        onSuccess: @escaping (RemoteControlResponse?) -> Void,
        onError: @escaping (String) -> Void
    ) {
        logger.debug("remote-control-assistant: Perform request")
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
