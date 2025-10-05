import Foundation

protocol DLiveWebSocketClientDelegate: AnyObject {
    func dliveWebSocketDidConnect()
    func dliveWebSocketDidDisconnect()
    func dliveWebSocketDidReceiveMessage(text: String)
}

final class DLiveWebSocketClient {
    private var socket: WebSocketClient
    weak var delegate: DLiveWebSocketClientDelegate?

    init(url: URL) {
        socket = WebSocketClient(url: url, protocols: ["graphql-ws"])
        socket.delegate = self
    }

    func connect() {
        socket.start()
    }

    func disconnect() {
        socket.stop()
    }

    func send(text: String) {
        socket.send(string: text)
    }

    func isSocketConnected() -> Bool {
        return socket.isConnected()
    }
}

extension DLiveWebSocketClient: WebSocketClientDelegate {
    func webSocketClientConnected(_: WebSocketClient) {
        logger.debug("dlive: websocket: Connected")
        delegate?.dliveWebSocketDidConnect()
    }

    func webSocketClientDisconnected(_: WebSocketClient) {
        logger.debug("dlive: websocket: Disconnected")
        delegate?.dliveWebSocketDidDisconnect()
    }

    func webSocketClientReceiveMessage(_: WebSocketClient, string: String) {
        logger.debug("dlive: websocket: Received message")
        delegate?.dliveWebSocketDidReceiveMessage(text: string)
    }
}
