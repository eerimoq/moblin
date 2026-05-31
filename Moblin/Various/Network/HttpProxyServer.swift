import Foundation
import Network

private let queue = DispatchQueue(label: "com.eerimoq.http-proxy-server")

class HttpConnectRequestParser: HttpParser {
    struct Result {
        let host: String
        let port: UInt16
        let version: String
        let bodyOffset: Int
    }

    func parse() -> (Bool, Result?) {
        var offset = 0
        guard let (startLine, nextOffset) = getLine(data: data, offset: offset) else {
            return (false, nil)
        }
        offset = nextOffset
        let parts = startLine.split(separator: " ")
        guard parts.count == 3, parts[0] == "CONNECT" else {
            return (true, nil)
        }
        let version = String(parts[2])
        guard version.hasPrefix("HTTP/1.") else {
            return (true, nil)
        }
        let hostPort = String(parts[1]).split(separator: ":", maxSplits: 1)
        guard hostPort.count == 2, let port = UInt16(hostPort[1]) else {
            return (true, nil)
        }
        let host = String(hostPort[0])
        while let (line, nextOffset) = getLine(data: data, offset: offset) {
            offset = nextOffset
            if line.isEmpty {
                return (true, Result(host: host, port: port, version: version, bodyOffset: offset))
            }
        }
        return (false, nil)
    }
}

private class Connection: @unchecked Sendable {
    private let client: NWConnection
    private let networkInterfaceTypeSelector: NetworkInterfaceTypeSelector
    private var destination: NWConnection?
    private var parser = HttpConnectRequestParser()
    private var tunneling = false
    private var body: Data?

    init(connection: NWConnection, networkInterfaceTypeSelector: NetworkInterfaceTypeSelector) {
        client = connection
        self.networkInterfaceTypeSelector = networkInterfaceTypeSelector
    }

    func start() {
        client.start(queue: queue)
        receiveFromClient()
    }

    private func stop() {
        client.cancel()
        destination?.cancel()
        destination = nil
    }

    private func receiveFromClient() {
        client.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
            guard error == nil else {
                self.stop()
                return
            }
            if let data, !data.isEmpty {
                if self.tunneling {
                    self.handleDataTunneling(data: data)
                } else {
                    self.handleDataConnecting(data: data)
                }
            } else if isComplete {
                self.stop()
            } else {
                self.receiveFromClient()
            }
        }
    }

    private func handleDataConnecting(data: Data) {
        parser.append(data: data)
        let (done, result) = parser.parse()
        guard done else {
            receiveFromClient()
            return
        }
        guard let result else {
            sendResponseAndStop("HTTP/1.1 400 Bad Request\r\n\r\n")
            return
        }
        connectToDestination(host: result.host, port: result.port, version: result.version)
        if result.bodyOffset < parser.data.count {
            body = Data(parser.data[result.bodyOffset...])
        }
    }

    private func handleDataTunneling(data: Data) {
        destination?.send(content: data, completion: .idempotent)
        receiveFromClient()
    }

    private func connectToDestination(host: String, port: UInt16, version: String) {
        let parameters: NWParameters = .tcp
        parameters.prohibitExpensivePaths = false
        let interfaceType = networkInterfaceTypeSelector.getType()
        if let interfaceType {
            parameters.requiredInterfaceType = interfaceType
        }
        let connection = NWConnection(
            to: .hostPort(host: .init(host), port: .init(integerLiteral: port)),
            using: parameters
        )
        destination = connection
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                self.tunneling = true
                self.sendResponse("\(version) 200 Connection Established\r\n\r\n")
                if let body = self.body {
                    self.destination?.send(content: body, completion: .idempotent)
                    self.body = nil
                }
                self.receiveFromClient()
                self.receiveFromDestination()
            case .failed:
                self.sendResponseAndStop("HTTP/1.1 502 Bad Gateway\r\n\r\n")
                if let interfaceType {
                    self.networkInterfaceTypeSelector.markBad(interfaceType: interfaceType)
                }
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    private func receiveFromDestination() {
        destination?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
            guard error == nil else {
                self.stop()
                return
            }
            if let data, !data.isEmpty {
                self.client.send(content: data, completion: .idempotent)
            }
            guard !isComplete else {
                self.stop()
                return
            }
            self.receiveFromDestination()
        }
    }

    private func sendResponse(_ response: String) {
        client.send(content: response.utf8Data, completion: .idempotent)
    }

    private func sendResponseAndStop(_ response: String) {
        client.send(content: response.utf8Data, completion: .contentProcessed { _ in
            self.stop()
        })
    }
}

class HttpProxyServer: @unchecked Sendable {
    private var listener: NWListener?
    private let retryTimer: SimpleTimer
    private var port: NWEndpoint.Port = .init(integerLiteral: 0)
    private var started = false
    private let networkInterfaceTypeSelector: NetworkInterfaceTypeSelector

    init() {
        retryTimer = SimpleTimer(queue: queue)
        networkInterfaceTypeSelector = NetworkInterfaceTypeSelector(queue: queue)
    }

    func start(port: NWEndpoint.Port) {
        queue.async {
            self.startInternal(port: port)
        }
    }

    func stop() {
        queue.async {
            self.stopInternal()
        }
    }

    private func startInternal(port: NWEndpoint.Port) {
        self.port = port
        started = true
        setupListener()
    }

    private func stopInternal() {
        started = false
        retryTimer.stop()
        listener?.cancel()
        listener = nil
    }

    private func setupListener() {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: NWEndpoint.Host("127.0.0.1"), port: port)
        listener = try? NWListener(using: parameters)
        listener?.stateUpdateHandler = handleStateUpdate
        listener?.newConnectionHandler = handleNewConnection
        listener?.start(queue: queue)
    }

    private func handleStateUpdate(_ newState: NWListener.State) {
        switch newState {
        case .failed:
            retryTimer.startSingleShot(timeout: 1) { [weak self] in
                guard let self, started else {
                    return
                }
                setupListener()
            }
        default:
            break
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        Connection(connection: connection,
                   networkInterfaceTypeSelector: networkInterfaceTypeSelector).start()
    }
}
