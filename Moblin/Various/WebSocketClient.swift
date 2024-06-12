import Network
import NWWebSocket
import SwiftUI
import TwitchChat

private let shortestDelayMs = 500
private let longestDelayMs = 10000

protocol WebSocketClientDelegate: AnyObject {
    func webSocketClientConnected()
    func webSocketClientDisconnected()
    func webSocketClientReceiveMessage(string: String)
}

final class WebSocketClient {
    private var webSocket: NWWebSocket
    private var connectTimer: DispatchSourceTimer?
    private var networkInterfaceTypeSelector = NetworkInterfaceTypeSelector(queue: .main)
    private var pingTimer: DispatchSourceTimer?
    private var pongReceived: Bool = true
    var delegate: (any WebSocketClientDelegate)?
    private let url: URL
    private var connected = false
    private var connectDelayMs = shortestDelayMs

    init(url: URL) {
        self.url = url
        webSocket = NWWebSocket(url: url, requiredInterfaceType: .cellular)
    }

    func start() {
        startInternal()
    }

    func stop() {
        stopInternal()
    }

    func isConnected() -> Bool {
        return connected
    }

    func send(string: String) {
        webSocket.send(string: string)
    }

    private func startInternal() {
        stopInternal()
        if let interfaceType = networkInterfaceTypeSelector.getNextType() {
            webSocket = NWWebSocket(url: url, requiredInterfaceType: interfaceType)
            logger.debug("websocket: Connecting to \(url) over \(interfaceType)")
            webSocket.delegate = self
            webSocket.connect()
            startPingTimer()
        } else {
            connectDelayMs = shortestDelayMs
            startConnectTimer()
        }
    }

    private func stopInternal() {
        connected = false
        webSocket.disconnect()
        webSocket = .init(url: url, requiredInterfaceType: .cellular)
        stopConnectTimer()
        stopPingTimer()
    }

    private func startConnectTimer() {
        connected = false
        connectTimer = DispatchSource.makeTimerSource(queue: .main)
        connectTimer!.schedule(deadline: .now().advanced(by: .milliseconds(connectDelayMs)))
        connectDelayMs *= 2
        if connectDelayMs > longestDelayMs {
            connectDelayMs = longestDelayMs
        }
        connectTimer!.setEventHandler { [weak self] in
            self?.startInternal()
        }
        connectTimer!.activate()
    }

    private func stopConnectTimer() {
        connectTimer?.cancel()
        connectTimer = nil
    }

    private func startPingTimer() {
        pongReceived = true
        pingTimer = DispatchSource.makeTimerSource(queue: .main)
        pingTimer!.schedule(deadline: .now(), repeating: 5)
        pingTimer!.setEventHandler { [weak self] in
            guard let self else {
                return
            }
            if self.pongReceived {
                self.pongReceived = false
                self.webSocket.ping()
            } else {
                self.startInternal()
                self.delegate?.webSocketClientDisconnected()
            }
        }
        pingTimer!.activate()
    }

    private func stopPingTimer() {
        pingTimer?.cancel()
        pingTimer = nil
    }
}

extension WebSocketClient: WebSocketConnectionDelegate {
    func webSocketDidConnect(connection _: WebSocketConnection) {
        logger.debug("websocket: Connected")
        connectDelayMs = shortestDelayMs
        stopConnectTimer()
        connected = true
        delegate?.webSocketClientConnected()
    }

    func webSocketDidDisconnect(connection _: WebSocketConnection,
                                closeCode _: NWProtocolWebSocket.CloseCode, reason _: Data?)
    {
        logger.debug("websocket: Disconnected")
        stopInternal()
        startConnectTimer()
        delegate?.webSocketClientDisconnected()
    }

    func webSocketViabilityDidChange(connection _: WebSocketConnection, isViable: Bool) {
        logger.debug("websocket: Viability changed to \(isViable)")
        guard !isViable else {
            return
        }
        stopInternal()
        startConnectTimer()
        delegate?.webSocketClientDisconnected()
    }

    func webSocketDidAttemptBetterPathMigration(result _: Result<WebSocketConnection, NWError>) {
        logger.debug("websocket: Better path migration")
    }

    func webSocketDidReceiveError(connection _: WebSocketConnection, error: NWError) {
        logger.debug("websocket: Error \(error.localizedDescription)")
        stopInternal()
        startConnectTimer()
        delegate?.webSocketClientDisconnected()
    }

    func webSocketDidReceivePong(connection _: WebSocketConnection) {
        pongReceived = true
    }

    func webSocketDidReceiveMessage(connection _: WebSocketConnection, string: String) {
        delegate?.webSocketClientReceiveMessage(string: string)
    }

    func webSocketDidReceiveMessage(connection _: WebSocketConnection, data _: Data) {}
}
