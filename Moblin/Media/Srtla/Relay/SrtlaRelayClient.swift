import Foundation
import Network

enum SrtlaRelayClientState: String {
    case none = "None"
    case connecting = "Connecting"
    case connected = "Connected"
    case wrongPassword = "Wrong password"
    case unknownError = "Unknown error"
}

protocol SrtlaRelayClientDelegate: AnyObject {
    func srtlaRelayClientConnected(settingsId: UUID, relayId: UUID, relayName: String)
    func srtlaRelayClientTunnelAdded(endpoint: NWEndpoint, relayId: UUID, relayName: String)
    func srtlaRelayClientTunnelRemoved(endpoint: NWEndpoint)
}

private struct SrtlaRelayRequestResponse {
    let onSuccess: (SrtlaRelayResponse?) -> Void
    let onError: (String) -> Void
}

class SrtlaRelayClient {
    private let settingsId: UUID
    private var serverUrl: URL
    private var password: String
    private weak var delegate: (any SrtlaRelayClientDelegate)?
    private var webSocket: WebSocketClient
    private var state: SrtlaRelayClientState = .none
    private var started = false
    private let reconnectTimer = SimpleTimer(queue: .main)
    private var requests: [Int: SrtlaRelayRequestResponse] = [:]
    private var relayId = UUID()
    private var relayName = ""
    private var relayBatteryPercentage: Int?
    private var nextId = 0
    private var destinationAddress: String?
    private var destinationPort: UInt16?
    private var tunnelEndpoint: NWEndpoint?

    init(settingsId: UUID, serverUrl: URL, password: String, delegate: SrtlaRelayClientDelegate) {
        self.settingsId = settingsId
        self.serverUrl = serverUrl
        self.password = password
        self.delegate = delegate
        webSocket = .init(url: serverUrl)
    }

    func start() {
        logger.info("srtla-relay-client: Start")
        started = true
        startInternal()
    }

    func stop() {
        logger.info("srtla-relay-client: Stop")
        stopInternal()
        started = false
    }

    func startTunnel(address: String, port: UInt16) {
        destinationAddress = address
        destinationPort = port
        startTunnelInternal()
    }

    func stopTunnel() {}

    func getStatus() -> (String, Int?) {
        return (relayName, relayBatteryPercentage)
    }

    func updateStatus() {
        performRequest(data: .status) { response in
            guard case let .status(batteryPercentage: batteryPercentage) = response else {
                return
            }
            self.relayBatteryPercentage = batteryPercentage
        } onError: { error in
            logger.info("srtla-relay-client: Status failed with \(error)")
        }
    }

    private func startInternal() {
        guard started else {
            return
        }
        stopInternal()
        setState(state: .connecting)
        webSocket = .init(url: serverUrl, cellular: false)
        webSocket.delegate = self
        webSocket.start()
    }

    private func stopInternal() {
        relayId = .init()
        relayName = ""
        relayBatteryPercentage = nil
        reconnectTimer.stop()
        setState(state: .none)
        webSocket.delegate = nil
        webSocket.stop()
        reportTunnelRemoved()
    }

    private func reconnect(reason: String) {
        logger.info("srtla-relay-client: Reconnecting soon with reason \(reason)")
        stopInternal()
        reconnectTimer.startSingleShot(timeout: 5.0) {
            self.startInternal()
        }
    }

    private func setState(state: SrtlaRelayClientState) {
        guard state != self.state else {
            return
        }
        logger.info("srtla-relay-client: State change \(self.state) -> \(state)")
        self.state = state
    }

    private func send(message: SrtlaRelayMessageToServer) {
        do {
            let message = try message.toJson()
            webSocket.send(string: message)
        } catch {
            logger.info("srtla-relay-client: Encode failed")
        }
    }

    private func handleMessage(message: String) throws {
        do {
            switch try SrtlaRelayMessageToClient.fromJson(data: message) {
            case let .hello(apiVersion: apiVersion, id: id, name: name, authentication: authentication):
                handleHello(apiVersion: apiVersion, id: id, name: name, authentication: authentication)
            case let .identified(result: result):
                if !handleIdentified(result: result) {
                    logger.info("srtla-relay-client: Failed to identify")
                    return
                }
                setState(state: .connected)
                updateStatus()
                startTunnelInternal()
                delegate?.srtlaRelayClientConnected(settingsId: settingsId, relayId: relayId, relayName: relayName)
            case let .response(id: id, result: result, data: data):
                try handleResponse(id: id, result: result, data: data)
            }
        } catch {
            logger.info("srtla-relay-client: Decode failed")
        }
    }

    private func handleHello(
        apiVersion _: String,
        id: UUID,
        name: String,
        authentication: SrtlaRelayAuthentication
    ) {
        relayId = id
        relayName = name
        let hash = remoteControlHashPassword(
            challenge: authentication.challenge,
            salt: authentication.salt,
            password: password
        )
        send(message: .identify(authentication: hash))
    }

    private func handleIdentified(result: SrtlaRelayResult) -> Bool {
        switch result {
        case .ok:
            return true
        case .wrongPassword:
            reconnect(reason: "Wrong password")
            setState(state: .wrongPassword)
        default:
            reconnect(reason: "Unknown error")
            setState(state: .unknownError)
        }
        return false
    }

    private func handleResponse(id: Int, result: SrtlaRelayResult, data: SrtlaRelayResponse?) throws {
        guard let request = requests[id] else {
            logger.info("srtla-relay-client: Unexpected id in response")
            return
        }
        switch result {
        case .ok:
            request.onSuccess(data)
        case .wrongPassword:
            request.onError("Wrong password")
        case .notIdentified:
            logger.info("srtla-relay-client: Not identified")
        case .alreadyIdentified:
            logger.info("srtla-relay-client: Already identified")
        case .unknownRequest:
            logger.info("srtla-relay-client: Unknown request")
        }
    }

    private func performRequest(
        data: SrtlaRelayRequest,
        onSuccess: @escaping (SrtlaRelayResponse?) -> Void,
        onError: @escaping (String) -> Void
    ) {
        let id = getNextId()
        requests[id] = SrtlaRelayRequestResponse(onSuccess: onSuccess, onError: onError)
        send(message: .request(id: id, data: data))
    }

    private func getNextId() -> Int {
        nextId += 1
        return nextId
    }

    private func startTunnelInternal() {
        guard let destinationAddress, let destinationPort else {
            return
        }
        reportTunnelRemoved()
        executeStartTunnel(address: destinationAddress, port: destinationPort) { _, _, port in
            guard let host = self.serverUrl.host else {
                logger.info("srtla-relay-client: Missing relay host")
                return
            }
            let endpoint = NWEndpoint.hostPort(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(integerLiteral: port)
            )
            self.tunnelEndpoint = endpoint
            self.delegate?.srtlaRelayClientTunnelAdded(
                endpoint: endpoint,
                relayId: self.relayId,
                relayName: self.relayName
            )
        }
    }

    private func reportTunnelRemoved() {
        if let tunnelEndpoint {
            delegate?.srtlaRelayClientTunnelRemoved(endpoint: tunnelEndpoint)
        }
        tunnelEndpoint = nil
    }

    private func executeStartTunnel(address: String, port: UInt16,
                                    onSuccess: @escaping (UUID, String, UInt16) -> Void)
    {
        logger.info("srtla-relay-client: Starting tunnel to destination \(address):\(port)")
        performRequest(data: .startTunnel(address: address, port: port)) { response in
            guard case let .startTunnel(port: port) = response else {
                return
            }
            onSuccess(self.relayId, self.relayName, port)
        } onError: { error in
            logger.info("srtla-relay-client: Start tunnel failed with \(error)")
        }
    }
}

extension SrtlaRelayClient: WebSocketClientDelegate {
    func webSocketClientConnected(_: WebSocketClient) {}

    func webSocketClientDisconnected(_: WebSocketClient) {
        reconnect(reason: "Disconnected")
    }

    func webSocketClientReceiveMessage(_: WebSocketClient, string: String) {
        try? handleMessage(message: string)
    }
}
