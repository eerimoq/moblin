import CryptoKit
import Foundation
import Telegraph

private struct RemoteControlRequestResponse {
    let onSuccess: (RemoteControlResponse?) -> Void
    let onError: (String) -> Void
}

class RemoteControlAssistant {
    private let address: String
    private let port: UInt16
    private let password: String
    private var connected: Bool = false
    private var nextId: Int = 0
    private var requests: [Int: RemoteControlRequestResponse] = [:]
    private var onConnected: () -> Void
    private var onDisconnected: () -> Void
    private var server: Server
    var connectionErrorMessage: String = ""
    private var websocket: Telegraph.WebSocket?

    init(
        address: String,
        port: UInt16,
        password: String,
        onConnected: @escaping () -> Void,
        onDisconnected: @escaping () -> Void
    ) {
        self.address = address
        self.port = port
        self.password = password
        self.onConnected = onConnected
        self.onDisconnected = onDisconnected
        server = Server()
        server.webSocketConfig.pingInterval = 30
        server.webSocketConfig.readTimeout = 60
        server.webSocketDelegate = self
    }

    func start() {
        stop()
        logger.info("remote-control-assistant: start")
        do {
            try server.start(port: Endpoint.Port(port), interface: address)
        } catch {
            logger.info("remote-control-assistant: Failed to start server with error \(error)")
        }
    }

    func stop() {
        logger.info("remote-control-assistant: stop")
        server.stop(immediately: true)
    }

    func isConnected() -> Bool {
        return connected
    }

    func getStatus(onSuccess: @escaping (RemoteControlStatusTopLeft, RemoteControlStatusTopRight) -> Void) {
        performRequest(data: .getStatus) { response in
            guard let response else {
                return
            }
            switch response {
            case let .getStatus(topLeft: topLeft, topRight: topRight):
                onSuccess(topLeft, topRight)
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

    private func handleConnected(webSocket: Telegraph.WebSocket) {
        logger.info("remote-control-assistant: Server connected")
        websocket = webSocket
    }

    private func handleDisconnected(webSocket _: Telegraph.WebSocket, error: Error?) {
        if let error {
            logger.info("remote-control-assistant: Server disconnected \(error)")
        } else {
            logger.info("remote-control-assistant: Server disconnected")
        }
        websocket = nil
        connected = false
        onDisconnected()
    }

    private func handleStringMessage(webSocket _: Telegraph.WebSocket, message: String) {
        logger.debug("remote-control-assistant: Got message \(message)")
        do {
            let message = try RemoteControlMessageToClient.fromJson(data: message)
            switch message {
            case let .event(data: data):
                try handleEvent(data: data)
            case let .response(id: id, result: result, data: data):
                handleResponse(id: id, result: result, data: data)
            }
        } catch {
            logger.info("remote-control-assistant: Failed to process message with error \(error)")
        }
    }

    private func handleEvent(data: RemoteControlEvent) throws {
        switch data {
        case let .hello(apiVersion: apiVersion, authentication: authentication):
            try handleHelloEvent(apiVersion: apiVersion, authentication: authentication)
        }
    }

    private func handleResponse(id: Int, result: RemoteControlResult, data: RemoteControlResponse?) {
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

    private func handleHelloEvent(apiVersion _: String, authentication: RemoteControlAuthentication) throws {
        let hash = remoteControlHashPassword(
            challenge: authentication.challenge,
            salt: authentication.salt,
            password: password
        )
        connected = true
        performRequest(data: .identify(authentication: hash)) { _ in
            self.onConnected()
        } onError: { message in
            logger.info("remote-control-assistant: error: \(message)")
        }
    }

    private func performRequest(
        data: RemoteControlRequest,
        onSuccess: @escaping (RemoteControlResponse?) -> Void,
        onError: @escaping (String) -> Void
    ) {
        logger.debug("remote-control-assistant: Perform request")
        guard connected else {
            onError("Not connected to server")
            return
        }
        let id = getNextId()
        let request: RemoteControlMessageToServer = .request(id: id, data: data)
        guard let message = request.toJson() else {
            return
        }
        requests[id] = RemoteControlRequestResponse(onSuccess: onSuccess, onError: onError)
        websocket?.send(text: message)
    }

    private func getNextId() -> Int {
        nextId += 1
        return nextId
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
        guard message.opcode == .textFrame else {
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
