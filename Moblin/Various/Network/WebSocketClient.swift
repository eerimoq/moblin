import Foundation
import Network

private let shortestDelayMs = 500
private let longestDelayMs = 10000

@MainActor
protocol WebSocketClientDelegate: AnyObject {
    func webSocketClientConnected(_ webSocket: WebSocketClient)
    func webSocketClientDisconnected(_ webSocket: WebSocketClient)
    func webSocketClientReceiveMessage(_ webSocket: WebSocketClient, string: String)
}

@MainActor
final class WebSocketClient {
    private var connection: NWConnection?
    private var connectTimer = MainTimer()
    private var networkInterfaceTypeSelector: NetworkInterfaceTypeSelector
    private var pingTimer = MainTimer()
    private var pongReceived = true
    private var closing = false
    weak var delegate: (any WebSocketClientDelegate)?
    private let url: URL
    private let loopback: Bool
    private var connected = false
    private var connectDelayMs = shortestDelayMs
    private let protocols: [String]?

    init(url: URL,
         loopback: Bool = false,
         cellular: Bool = true,
         protocols: [String]? = nil)
    {
        self.url = url
        self.loopback = loopback
        self.protocols = protocols
        networkInterfaceTypeSelector = NetworkInterfaceTypeSelector(queue: .main, cellular: cellular)
    }

    func start() {
        startInternal()
    }

    func stop(closeCode: NWProtocolWebSocket.CloseCode = .protocolCode(.normalClosure)) {
        guard let connection, connected else {
            stopInternal()
            return
        }
        logger.debug("websocket: Closing with code \(closeCode)")
        connected = false
        closing = true
        stopConnectTimer()
        stopPingTimer()
        let metadata = NWProtocolWebSocket.Metadata(opcode: .close)
        metadata.closeCode = closeCode
        send(connection, nil, metadata)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            connection.cancel()
        }
    }

    func isConnected() -> Bool {
        connected
    }

    func send(string: String) {
        guard let connection, !closing else {
            return
        }
        send(connection, string.utf8Data, NWProtocolWebSocket.Metadata(opcode: .text))
    }

    private func startInternal() {
        stopInternal()
        if var interfaceType = networkInterfaceTypeSelector.getNextType() {
            if loopback {
                interfaceType = .loopback
            }
            logger.debug("websocket: Connecting to \(url) over \(interfaceType)")
            let parameters = createParameters(interfaceType: interfaceType)
            let connection = NWConnection(to: .url(url), using: parameters)
            connection.stateUpdateHandler = { [weak self] state in
                guard let self else {
                    return
                }
                MainActor.assumeIsolated {
                    handleStateUpdate(connection, state)
                }
            }
            connection.viabilityUpdateHandler = { [weak self] isViable in
                guard let self else {
                    return
                }
                MainActor.assumeIsolated {
                    handleViabilityUpdate(connection, isViable)
                }
            }
            self.connection = connection
            receiveMessage(connection)
            connection.start(queue: .main)
            startPingTimer()
        } else {
            connectDelayMs = shortestDelayMs
            startConnectTimer()
        }
    }

    private func stopInternal() {
        connected = false
        closing = false
        connection?.stateUpdateHandler = nil
        connection?.viabilityUpdateHandler = nil
        connection?.cancel()
        connection = nil
        stopConnectTimer()
        stopPingTimer()
    }

    private func createParameters(interfaceType: NWInterface.InterfaceType) -> NWParameters {
        let options = NWProtocolWebSocket.Options()
        options.autoReplyPing = true
        if let protocols {
            options.setSubprotocols(protocols)
        }
        let parameters: NWParameters = url.scheme == "ws" ? .tcp : .tls
        parameters.defaultProtocolStack.applicationProtocols.insert(options, at: 0)
        parameters.requiredInterfaceType = interfaceType
        return parameters
    }

    private func handleStateUpdate(_ connection: NWConnection, _ state: NWConnection.State) {
        guard connection === self.connection else {
            return
        }
        switch state {
        case .ready:
            logger.debug("websocket: Connected")
            connectDelayMs = shortestDelayMs
            stopConnectTimer()
            connected = true
            delegate?.webSocketClientConnected(self)
        case let .waiting(error):
            logger.debug("websocket: Waiting with error \(error.localizedDescription)")
            handleDisconnected()
        case let .failed(error):
            logger.debug("websocket: Failed with error \(error.localizedDescription)")
            handleDisconnected()
        case .cancelled:
            logger.debug("websocket: Cancelled")
            handleDisconnected()
        default:
            break
        }
    }

    private func handleViabilityUpdate(_ connection: NWConnection, _ isViable: Bool) {
        guard connection === self.connection else {
            return
        }
        logger.debug("websocket: Viability changed to \(isViable)")
        guard !isViable else {
            return
        }
        handleDisconnected()
    }

    private func handleDisconnected() {
        if closing {
            stopInternal()
        } else {
            let connected = connected
            stopInternal()
            startConnectTimer()
            if connected {
                delegate?.webSocketClientDisconnected(self)
            }
        }
    }

    private func receiveMessage(_ connection: NWConnection) {
        connection.receiveMessage { [weak self] data, context, _, error in
            guard let self else {
                connection.cancel()
                return
            }
            MainActor.assumeIsolated {
                handleMessage(connection, data, context, error)
            }
        }
    }

    private func handleMessage(_ connection: NWConnection,
                               _ data: Data?,
                               _ context: NWConnection.ContentContext?,
                               _ error: NWError?)
    {
        guard connection === self.connection else {
            return
        }
        if let error {
            logger.debug("websocket: Receive error \(error.localizedDescription)")
            handleDisconnected()
            return
        }
        if let metadata = context?.protocolMetadata.first as? NWProtocolWebSocket.Metadata {
            switch metadata.opcode {
            case .text:
                if !closing, let data, let string = String(data: data, encoding: .utf8) {
                    delegate?.webSocketClientReceiveMessage(self, string: string)
                }
            case .close:
                logger.debug("websocket: Close received")
                handleDisconnected()
                return
            default:
                break
            }
        }
        receiveMessage(connection)
    }

    private func send(_ connection: NWConnection, _ data: Data?, _ metadata: NWProtocolWebSocket.Metadata) {
        let context = NWConnection.ContentContext(identifier: "websocket", metadata: [metadata])
        let completion = NWConnection.SendCompletion.contentProcessed { [weak self] error in
            guard let self, let error else {
                return
            }
            MainActor.assumeIsolated {
                handleSendError(connection, error)
            }
        }
        connection.send(content: data, contentContext: context, isComplete: true, completion: completion)
    }

    private func handleSendError(_ connection: NWConnection, _ error: NWError) {
        guard connection === self.connection else {
            return
        }
        logger.debug("websocket: Send error \(error.localizedDescription)")
        handleDisconnected()
    }

    private func sendPing(_ connection: NWConnection) {
        let metadata = NWProtocolWebSocket.Metadata(opcode: .ping)
        metadata.setPongHandler(.main) { [weak self] error in
            guard let self, error == nil else {
                return
            }
            MainActor.assumeIsolated {
                guard connection === self.connection else {
                    return
                }
                pongReceived = true
            }
        }
        send(connection, "ping".utf8Data, metadata)
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
            guard let self, let connection else {
                return
            }
            if pongReceived {
                pongReceived = false
                sendPing(connection)
            } else {
                logger.debug("websocket: Pong not received")
                let connected = connected
                startInternal()
                if connected {
                    delegate?.webSocketClientDisconnected(self)
                }
            }
        }
    }

    private func stopPingTimer() {
        pingTimer.stop()
    }
}
