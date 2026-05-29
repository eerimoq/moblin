import Collections
import CryptoKit
import Foundation
import Network

private let moblinkRequestTimeout = 10.0

protocol MoblinkStreamerDelegate: AnyObject {
    func moblinkStreamerTunnelAdded(endpoint: NWEndpoint, relayId: UUID, relayName: String)
    func moblinkStreamerTunnelRemoved(endpoint: NWEndpoint)
    func moblinkStreamerWebProxyRelaysChanged(relays: [WebNetworkMoblinkRelay])
}

private struct RequestResponse {
    let onSuccess: (MoblinkResponse?) -> Void
    let onError: (String) -> Void
}

private final class MoblinkWebProxyConnection: WebNetworkMoblinkConnection {
    let id: UUID
    private weak var relay: Relay?
    private weak var delegate: (any WebNetworkMoblinkConnectionDelegate)?

    init(id: UUID, relay: Relay, delegate: any WebNetworkMoblinkConnectionDelegate) {
        self.id = id
        self.relay = relay
        self.delegate = delegate
    }

    func send(data: Data) {
        DispatchQueue.main.async {
            self.relay?.sendWebProxyData(id: self.id, data: data)
        }
    }

    func close() {
        DispatchQueue.main.async {
            self.relay?.closeWebProxyConnection(id: self.id, notifyRelay: true, notifyDelegate: false)
        }
    }

    func receive(data: Data) {
        delegate?.webNetworkMoblinkConnectionReceiveData(data: data)
    }

    func closeFromRelay() {
        delegate?.webNetworkMoblinkConnectionClosed()
    }
}

private class Relay {
    let webSocket: NWConnection
    private var nextId: Int = 0
    private var identified = false
    private var challenge = ""
    private var salt = ""
    private var requests: [Int: RequestResponse] = [:]
    private var requestTimers: [Int: SimpleTimer] = [:]
    private let password: String
    private var address: String?
    private var port: UInt16?
    weak var streamer: MoblinkStreamer?
    private var tunnelEndpoint: NWEndpoint?
    var relayId = UUID()
    var name = ""
    var batteryPercentage: Int?
    var thermalState: MoblinkThermalState?
    private var webProxyCapable = false
    private var webProxyConnections: [UUID: MoblinkWebProxyConnection] = [:]
    private var pingTimer = SimpleTimer(queue: .main)
    var pongReceived = true

    init(webSocket: NWConnection, password: String, streamer: MoblinkStreamer) {
        self.password = password
        self.webSocket = webSocket
        self.streamer = streamer
    }

    func start() {
        challenge = randomString()
        salt = randomString()
        send(message: .hello(
            apiVersion: remoteControlApiVersion,
            authentication: .init(challenge: challenge, salt: salt)
        ))
        identified = false
        startPingTimer()
    }

    func stop() {
        stopPingTimer()
        webSocket.cancel()
        reportTunnelRemoved()
        requests.removeAll()
        stopRequestTimers()
        closeWebProxyConnections(notifyRelay: false, notifyDelegate: true)
    }

    func handleStringMessage(message: String) {
        // logger.debug("moblink-streamer: Received \(message)")
        do {
            let message = try MoblinkMessageToStreamer.fromJson(data: message)
            switch message {
            case let .identify(id: relayId,
                               name: name,
                               authentication: authentication,
                               capabilities: capabilities):
                try handleIdentify(relayId: relayId,
                                   name: name,
                                   authentication: authentication,
                                   capabilities: capabilities)
            case let .response(id: id, result: result, data: data):
                try handleResponse(id: id, result: result, data: data)
            case let .webProxyData(id: id, data: data):
                handleWebProxyData(id: id, data: data)
            case let .webProxyClose(id: id):
                closeWebProxyConnection(id: id, notifyRelay: false, notifyDelegate: true)
            }
        } catch {
            logger.info("moblink-streamer: \(name): Failed to process message with error \(error)")
            webSocket.cancel()
        }
    }

    func startTunnel(address: String, port: UInt16) {
        self.address = address
        self.port = port
        startTunnelInternal()
    }

    func stopTunnel() {
        reportTunnelRemoved()
    }

    func updateStatus() {
        performRequest(data: .status) { response in
            guard case let .status(batteryPercentage, thermalState) = response else {
                return
            }
            self.batteryPercentage = batteryPercentage
            self.thermalState = thermalState
        } onError: { error in
            logger.info("moblink-streamer: \(self.name): Status failed with \(error)")
        }
    }

    func webProxyRelay() -> WebNetworkMoblinkRelay? {
        guard identified, webProxyCapable else {
            return nil
        }
        return .init(id: relayId, name: name)
    }

    func openWebProxyConnection(host: String,
                                port: UInt16,
                                delegate: any WebNetworkMoblinkConnectionDelegate,
                                completion: @escaping ((any WebNetworkMoblinkConnection)?) -> Void)
    {
        guard identified, webProxyCapable else {
            completion(nil)
            return
        }
        let id = UUID()
        let connection = MoblinkWebProxyConnection(id: id, relay: self, delegate: delegate)
        webProxyConnections[id] = connection
        performRequest(data: .webProxyOpen(id: id, host: host, port: port)) { response in
            guard case let .webProxyOpen(responseId) = response,
                  responseId == id,
                  let currentConnection = self.webProxyConnections[id],
                  currentConnection === connection
            else {
                self.closeWebProxyConnection(id: id, notifyRelay: false, notifyDelegate: false)
                completion(nil)
                return
            }
            completion(connection)
        } onError: { error in
            logger.info("moblink-streamer: \(self.name): Web proxy open failed with \(error)")
            self.closeWebProxyConnection(id: id, notifyRelay: false, notifyDelegate: false)
            completion(nil)
        }
    }

    func sendWebProxyData(id: UUID, data: Data) {
        send(message: .webProxyData(id: id, data: data))
    }

    func closeWebProxyConnection(id: UUID, notifyRelay: Bool, notifyDelegate: Bool) {
        guard let connection = webProxyConnections.removeValue(forKey: id) else {
            return
        }
        if notifyRelay {
            send(message: .webProxyClose(id: id))
        }
        if notifyDelegate {
            connection.closeFromRelay()
        }
    }

    private func startPingTimer() {
        pongReceived = true
        pingTimer.startPeriodic(interval: 10, initial: 0) { [weak self] in
            guard let self else {
                return
            }
            if pongReceived {
                pongReceived = false
                webSocket.sendWebSocket(data: nil, opcode: .ping)
            } else {
                logger.info("moblink-streamer: \(name): Ping timeout")
                webSocket.cancel()
            }
        }
    }

    private func stopPingTimer() {
        pingTimer.stop()
    }

    private func handleWebProxyData(id: UUID, data: Data) {
        webProxyConnections[id]?.receive(data: data)
    }

    private func closeWebProxyConnections(notifyRelay: Bool, notifyDelegate: Bool) {
        for id in Array(webProxyConnections.keys) {
            closeWebProxyConnection(id: id, notifyRelay: notifyRelay, notifyDelegate: notifyDelegate)
        }
    }

    private func startTunnelInternal() {
        guard identified, let address, let port else {
            return
        }
        reportTunnelRemoved()
        executeStartTunnel(address: address, port: port) { id, name, port in
            switch self.webSocket.endpoint {
            case let .hostPort(host: host, port: _):
                let endpoint = NWEndpoint.hostPort(
                    host: host,
                    port: NWEndpoint.Port(integerLiteral: port)
                )
                self.tunnelEndpoint = endpoint
                self.streamer?.delegate?.moblinkStreamerTunnelAdded(
                    endpoint: endpoint,
                    relayId: id,
                    relayName: name
                )
            default:
                logger.info("moblink-streamer: \(name): Missing relay host")
            }
        }
    }

    private func reportTunnelRemoved() {
        if let tunnelEndpoint {
            streamer?.delegate?.moblinkStreamerTunnelRemoved(endpoint: tunnelEndpoint)
        }
        tunnelEndpoint = nil
    }

    private func executeStartTunnel(address: String,
                                    port: UInt16,
                                    onSuccess: @escaping (UUID, String, UInt16) -> Void)
    {
        logger.info("moblink-streamer: \(name): Starting tunnel to destination \(address):\(port)")
        performRequest(data: .startTunnel(address: address, port: port)) { response in
            guard case let .startTunnel(port: port) = response else {
                return
            }
            onSuccess(self.relayId, self.name, port)
        } onError: { error in
            logger.info("moblink-streamer: \(self.name): Start tunnel failed with \(error)")
        }
    }

    private func handleIdentify(relayId: UUID,
                                name: String,
                                authentication: String,
                                capabilities: [MoblinkCapability]?) throws
    {
        if authentication == remoteControlHashPassword(
            challenge: challenge,
            salt: salt,
            password: password
        ) {
            streamer?.removeRelay(relayId: relayId)
            self.relayId = relayId
            self.name = String(name.prefix(while: { $0 != "\n" }).trim().prefix(30))
            identified = true
            webProxyCapable = capabilities?.contains(.webProxy) == true
            if webProxyCapable {
                logger.info("moblink-streamer: \(self.name): Web proxy relay supported")
            }
            send(message: .identified(result: .ok))
            startTunnelInternal()
            updateStatus()
            streamer?.updateWebProxyRelays()
        } else {
            send(message: .identified(result: .wrongPassword))
            throw "Relay sent wrong password"
        }
    }

    private func handleResponse(id: Int, result: MoblinkResult, data: MoblinkResponse?) throws {
        guard identified else {
            throw "Relay not identified"
        }
        guard let request = requests.removeValue(forKey: id) else {
            logger.info("moblink-streamer: \(name): Unexpected id in response")
            return
        }
        requestTimers.removeValue(forKey: id)?.stop()
        switch result {
        case .ok:
            request.onSuccess(data)
        case .wrongPassword:
            request.onError("Wrong password")
        case .notIdentified:
            logger.info("moblink-streamer: \(name): Not identified")
            request.onError("Not identified")
        case .alreadyIdentified:
            logger.info("moblink-streamer: \(name): Already identified")
            request.onError("Already identified")
        case .unknownRequest:
            logger.info("moblink-streamer: \(name): Unknown request")
            request.onError("Unknown request")
        }
    }

    private func performRequest(
        data: MoblinkRequest,
        onSuccess: @escaping (MoblinkResponse?) -> Void,
        onError: @escaping (String) -> Void
    ) {
        let id = getNextId()
        requests[id] = RequestResponse(onSuccess: onSuccess, onError: onError)
        startRequestTimer(id: id)
        send(message: .request(id: id, data: data))
    }

    private func startRequestTimer(id: Int) {
        let timer = SimpleTimer(queue: .main)
        requestTimers[id] = timer
        timer.startSingleShot(timeout: moblinkRequestTimeout) { [weak self] in
            guard let self,
                  let request = requests.removeValue(forKey: id)
            else {
                return
            }
            requestTimers.removeValue(forKey: id)
            request.onError("Timeout")
        }
    }

    private func stopRequestTimers() {
        for timer in requestTimers.values {
            timer.stop()
        }
        requestTimers.removeAll()
    }

    private func getNextId() -> Int {
        nextId += 1
        return nextId
    }

    private func send(message: MoblinkMessageToRelay) {
        guard let text = message.toJson() else {
            return
        }
        // logger.info("moblink-streamer: Sending \(text)")
        webSocket.sendWebSocket(data: text.data(using: .utf8), opcode: .text)
    }
}

private let idStorage = SimpleStringStorage(key: "moblinkServerId")

class MoblinkStreamer: NSObject, @unchecked Sendable {
    private let port: UInt16
    private let password: String
    private let name: String
    private var server: NWListener?
    var connectionErrorMessage = ""
    private var retryStartTimer = SimpleTimer(queue: .main)
    fileprivate weak var delegate: (any MoblinkStreamerDelegate)?
    private var relays: [Relay] = []
    private var destinationAddress: String?
    private var destinationPort: UInt16?

    init(port: UInt16, password: String, name: String) {
        self.port = port
        self.password = password
        self.name = name
        super.init()
        if idStorage.get().isEmpty {
            idStorage.set(UUID().uuidString)
        }
    }

    func start(delegate: any MoblinkStreamerDelegate) {
        stop()
        logger.debug("moblink-streamer: start")
        self.delegate = delegate
        startInternal()
    }

    func stop() {
        logger.debug("moblink-streamer: stop")
        server?.cancel()
        server = nil
        stopRetryStartTimer()
        for relay in relays {
            relay.stop()
        }
        relays.removeAll()
        updateWebProxyRelays()
        delegate = nil
    }

    func startTunnels(address: String, port: UInt16) {
        destinationAddress = address
        destinationPort = port
        for relay in relays {
            relay.startTunnel(address: address, port: port)
        }
    }

    func stopTunnels() {
        destinationAddress = nil
        destinationPort = nil
        for relay in relays {
            relay.stopTunnel()
        }
    }

    func getStatuses() -> [(String, Int?, MoblinkThermalState?)] {
        relays
            .sorted(by: { $0.name < $1.name })
            .map { ($0.name, $0.batteryPercentage, $0.thermalState) }
    }

    func updateWebProxyRelays() {
        let webProxyRelays = relays.compactMap { $0.webProxyRelay() }
        delegate?.moblinkStreamerWebProxyRelaysChanged(relays: webProxyRelays)
    }

    func updateStatus() {
        for relay in relays {
            relay.updateStatus()
        }
    }

    private func startInternal() {
        do {
            let parameters = NWParameters.tcp
            let options = NWProtocolWebSocket.Options()
            options.autoReplyPing = true
            parameters.defaultProtocolStack.applicationProtocols.append(options)
            server = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
            server?.service = NWListener.Service(
                name: idStorage.get(),
                type: moblinkBonjourType,
                domain: moblinkBonjourDomain,
                txtRecord: NWTXTRecord(["name": name])
            )
            server?.newConnectionHandler = handleNewConnection
            server?.start(queue: .main)
            stopRetryStartTimer()
        } catch {
            logger.debug("moblink-streamer: Failed to start server with error \(error)")
            connectionErrorMessage = error.localizedDescription
            startRetryStartTimer()
        }
    }

    private func startRetryStartTimer() {
        retryStartTimer.startSingleShot(timeout: 5) {
            self.startInternal()
        }
    }

    private func stopRetryStartTimer() {
        retryStartTimer.stop()
    }

    private func handleNewConnection(connection: NWConnection) {
        logger.debug("moblink-streamer: Relay connected")
        connection.start(queue: .main)
        receivePacket(webSocket: connection)
        let relay = Relay(webSocket: connection, password: password, streamer: self)
        relay.start()
        relays.append(relay)
        guard let destinationAddress, let destinationPort else {
            return
        }
        relay.startTunnel(address: destinationAddress, port: destinationPort)
    }

    func removeRelay(relayId: UUID) {
        if let relay = relays.first(where: { $0.relayId == relayId }) {
            logger.debug("moblink-streamer: Replacing relay \(relay.name) (id: \(relayId))")
            relay.stop()
        }
        relays.removeAll(where: { $0.relayId == relayId })
        updateWebProxyRelays()
    }

    private func handlePong(webSocket: NWConnection) {
        if let relay = relays.first(where: { $0.webSocket === webSocket }) {
            relay.pongReceived = true
        }
    }

    private func handleDisconnected(webSocket: NWConnection) {
        logger.debug("moblink-streamer: Relay disconnected")
        if let relay = relays.first(where: { $0.webSocket === webSocket }) {
            relay.stop()
        }
        relays.removeAll(where: { $0.webSocket === webSocket })
        updateWebProxyRelays()
    }

    private func receivePacket(webSocket: NWConnection) {
        webSocket.receiveMessage { data, context, _, _ in
            switch context?.webSocketOperation() {
            case .text:
                if let data, !data.isEmpty {
                    self.handleMessage(webSocket: webSocket, packet: data)
                    self.receivePacket(webSocket: webSocket)
                } else {
                    self.handleDisconnected(webSocket: webSocket)
                }
            case .ping:
                webSocket.sendWebSocket(data: data, opcode: .pong)
                self.receivePacket(webSocket: webSocket)
            case .pong:
                self.handlePong(webSocket: webSocket)
                self.receivePacket(webSocket: webSocket)
            default:
                self.handleDisconnected(webSocket: webSocket)
            }
        }
    }

    private func handleMessage(webSocket: NWConnection, packet: Data) {
        if let text = String(bytes: packet, encoding: .utf8) {
            guard let relay = relays.first(where: { $0.webSocket === webSocket }) else {
                return
            }
            relay.handleStringMessage(message: text)
        }
    }
}

extension MoblinkStreamer: WebNetworkMoblinkRelayConnector {
    func openWebProxyConnection(
        relayId: UUID,
        host: String,
        port: UInt16,
        delegate: any WebNetworkMoblinkConnectionDelegate,
        completion: @escaping ((any WebNetworkMoblinkConnection)?) -> Void
    ) {
        DispatchQueue.main.async {
            guard let relay = self.relays.first(where: { $0.relayId == relayId }) else {
                completion(nil)
                return
            }
            relay.openWebProxyConnection(host: host, port: port, delegate: delegate, completion: completion)
        }
    }
}
