import Collections
import Foundation

private struct MessageType: Decodable {
    let type: String
}

private struct MessageConnectData: Decodable {
    let connectionId: String
}

private struct MessageConnect: Decodable {
    let data: MessageConnectData
}

private class Connection {
    private let baseUrl: String
    private let bridgeId: String
    private let connectionId: String
    private let assistantUrl: URL
    private var relayDataWebsocket: WebSocketClient
    private var assistantWebsocket: WebSocketClient

    init(baseUrl: String, bridgeId: String, connectionId: String, assistantUrl: URL) {
        self.baseUrl = baseUrl
        self.bridgeId = bridgeId
        self.connectionId = connectionId
        self.assistantUrl = assistantUrl
        relayDataWebsocket = .init(url: URL(string: "wss://foo.bar")!)
        assistantWebsocket = .init(url: assistantUrl)
    }

    func setupRelayDataWebsocket() {
        guard let url = URL(string: "\(baseUrl)/bridge/data/\(bridgeId)/\(connectionId)") else {
            return
        }
        relayDataWebsocket = .init(url: url)
        relayDataWebsocket.delegate = self
        relayDataWebsocket.start()
    }

    func close() {
        relayDataWebsocket.stop()
        assistantWebsocket.stop()
    }

    private func setupAssistantWebsocket() {
        assistantWebsocket = .init(url: assistantUrl, loopback: true)
        assistantWebsocket.delegate = self
        assistantWebsocket.start()
    }
}

extension Connection: WebSocketClientDelegate {
    func webSocketClientConnected(_ webSocket: WebSocketClient) {
        if webSocket === relayDataWebsocket {
            setupAssistantWebsocket()
        }
    }

    func webSocketClientDisconnected(_: WebSocketClient) {
        close()
    }

    func webSocketClientReceiveMessage(_ webSocket: WebSocketClient, string: String) {
        if webSocket === relayDataWebsocket {
            assistantWebsocket.send(string: string)
        } else if webSocket === assistantWebsocket {
            relayDataWebsocket.send(string: string)
        }
    }
}

class RemoteControlRelay {
    private let baseUrl: String
    private let bridgeId: String
    private let assistantUrl: URL
    private let controlUrl: URL
    private var controlWebsocket: WebSocketClient
    private var connections: Deque<Connection> = []

    init?(baseUrl: String, bridgeId: String, assistantUrl: URL) {
        self.baseUrl = baseUrl
        self.bridgeId = bridgeId
        self.assistantUrl = assistantUrl
        guard let controlUrl = URL(string: "\(baseUrl)/bridge/control/\(bridgeId)") else {
            return nil
        }
        self.controlUrl = controlUrl
        controlWebsocket = .init(url: controlUrl)
    }

    func start() {
        stop()
        controlWebsocket = .init(url: controlUrl)
        controlWebsocket.delegate = self
        controlWebsocket.start()
    }

    func stop() {
        controlWebsocket.stop()
        for connection in connections {
            connection.close()
        }
    }

    private func handleControlMessage(message: String) throws {
        guard let message = message.data(using: .utf8) else {
            return
        }
        let decoded = try JSONDecoder().decode(MessageType.self, from: message)
        switch decoded.type {
        case "connect":
            try handleControlMessageConnect(message: message)
        default:
            break
        }
    }

    private func handleControlMessageConnect(message: Data) throws {
        let message = try JSONDecoder().decode(MessageConnect.self, from: message)
        let connection = Connection(
            baseUrl: baseUrl,
            bridgeId: bridgeId,
            connectionId: message.data.connectionId,
            assistantUrl: assistantUrl
        )
        connection.setupRelayDataWebsocket()
        connections.append(connection)
        if connections.count > 5 {
            connections.popFirst()?.close()
        }
    }
}

extension RemoteControlRelay: WebSocketClientDelegate {
    func webSocketClientConnected(_: WebSocketClient) {
        logger.info("remote-control-relay: Control connected.")
    }

    func webSocketClientDisconnected(_: WebSocketClient) {
        logger.info("remote-control-relay: Control disconnected.")
    }

    func webSocketClientReceiveMessage(_: WebSocketClient, string: String) {
        do {
            try handleControlMessage(message: string)
        } catch {
            logger.debug("remote-control-relay: Control error \(error)")
        }
    }
}
