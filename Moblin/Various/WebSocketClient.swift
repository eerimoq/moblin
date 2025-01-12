import Network
import NWWebSocket
import SwiftUI
import TwitchChat

private let shortestDelayMs = 500
private let longestDelayMs = 10000

protocol WebSocketClientDelegate: AnyObject {
    func webSocketClientConnected(_ webSocket: WebSocketClient)
    func webSocketClientDisconnected(_ webSocket: WebSocketClient)
    func webSocketClientReceiveMessage(_ webSocket: WebSocketClient, string: String)
}

final class WebSocketClient {
    private var webSocket: NWWebSocket
    private var connectTimer = SimpleTimer(queue: .main)
    private var networkInterfaceTypeSelector: NetworkInterfaceTypeSelector
    private var pingTimer = SimpleTimer(queue: .main)
    private var pongReceived = true
    var delegate: (any WebSocketClientDelegate)?
    private let url: URL
    private let loopback: Bool
    private var connected = false
    private var connectDelayMs = shortestDelayMs
    private let proxyConfig: NWWebSocketProxyConfig?

    init(url: URL, httpProxy: HttpProxy? = nil, loopback: Bool = false, cellular: Bool = true) {
        self.url = url
        self.loopback = loopback
        networkInterfaceTypeSelector = NetworkInterfaceTypeSelector(queue: .main, cellular: cellular)
        if let httpProxy {
            proxyConfig = NWWebSocketProxyConfig(endpoint: .hostPort(
                host: .init(httpProxy.host),
                port: .init(integerLiteral: httpProxy.port)
            ))
        } else {
            proxyConfig = nil
        }
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
        if var interfaceType = networkInterfaceTypeSelector.getNextType() {
            if loopback {
                interfaceType = .loopback
            }
            webSocket = NWWebSocket(url: url, requiredInterfaceType: interfaceType, proxyConfig: proxyConfig)
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
        connectTimer.startSingleShot(timeout: Double(connectDelayMs) / 1000) { [weak self] in
            self?.startInternal()
        }
        connectDelayMs *= 2
        if connectDelayMs > longestDelayMs {
            connectDelayMs = longestDelayMs
        }
    }

    private func stopConnectTimer() {
        connectTimer.stop()
    }

    private func startPingTimer() {
        pongReceived = true
        pingTimer.startPeriodic(interval: 10, initial: 0) { [weak self] in
            guard let self else {
                return
            }
            if self.pongReceived {
                self.pongReceived = false
                self.webSocket.ping()
            } else {
                self.startInternal()
                self.delegate?.webSocketClientDisconnected(self)
            }
        }
    }

    private func stopPingTimer() {
        pingTimer.stop()
    }
}

extension WebSocketClient: WebSocketConnectionDelegate {
    func webSocketDidConnect(connection _: WebSocketConnection) {
        logger.debug("websocket: Connected")
        connectDelayMs = shortestDelayMs
        stopConnectTimer()
        connected = true
        delegate?.webSocketClientConnected(self)
    }

    func webSocketDidDisconnect(connection _: WebSocketConnection,
                                closeCode _: NWProtocolWebSocket.CloseCode, reason _: Data?)
    {
        logger.debug("websocket: Disconnected")
        stopInternal()
        startConnectTimer()
        delegate?.webSocketClientDisconnected(self)
    }

    func webSocketViabilityDidChange(connection _: WebSocketConnection, isViable: Bool) {
        logger.debug("websocket: Viability changed to \(isViable)")
        guard !isViable else {
            return
        }
        stopInternal()
        startConnectTimer()
        delegate?.webSocketClientDisconnected(self)
    }

    func webSocketDidAttemptBetterPathMigration(result _: Result<WebSocketConnection, NWError>) {
        logger.debug("websocket: Better path migration")
    }

    func webSocketDidReceiveError(connection _: WebSocketConnection, error: NWError) {
        logger.debug("websocket: Error \(error.localizedDescription)")
        let connected = self.connected
        stopInternal()
        startConnectTimer()
        if connected {
            delegate?.webSocketClientDisconnected(self)
        }
    }

    func webSocketDidReceivePong(connection _: WebSocketConnection) {
        pongReceived = true
    }

    func webSocketDidReceiveMessage(connection _: WebSocketConnection, string: String) {
        delegate?.webSocketClientReceiveMessage(self, string: string)
    }

    func webSocketDidReceiveMessage(connection _: WebSocketConnection, data _: Data) {}
}
