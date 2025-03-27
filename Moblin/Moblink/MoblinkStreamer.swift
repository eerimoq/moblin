import Collections
import CryptoKit
import Foundation
import Network
import SwiftUI
import UIKit

protocol MoblinkStreamerDelegate: AnyObject {
    func moblinkStreamerTunnelAdded(endpoint: NWEndpoint, relayId: UUID, relayName: String)
    func moblinkStreamerTunnelRemoved(endpoint: NWEndpoint)
}

private struct RequestResponse {
    let onSuccess: (MoblinkResponse?) -> Void
    let onError: (String) -> Void
}

private class Relay {
    let webSocket: NWConnectionWithId
    private var nextId: Int = 0
    private var identified = false
    private var challenge = ""
    private var salt = ""
    private var requests: [Int: RequestResponse] = [:]
    private let password: String
    private var address: String?
    private var port: UInt16?
    weak var streamer: MoblinkStreamer?
    private var tunnelEndpoint: NWEndpoint?
    private var relayId = UUID()
    var name = ""
    var batteryPercentage: Int?

    init(webSocket: NWConnectionWithId, password: String, streamer: MoblinkStreamer) {
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
    }

    func stop() {
        webSocket.connection.cancel()
        reportTunnelRemoved()
        requests.removeAll()
    }

    func handleStringMessage(message: String) {
        // logger.info("moblink-streamer: Received \(message)")
        do {
            let message = try MoblinkMessageToStreamer.fromJson(data: message)
            switch message {
            case let .identify(id: relayId, name: name, authentication: authentication):
                try handleIdentify(relayId: relayId, name: name, authentication: authentication)
            case let .response(id: id, result: result, data: data):
                try handleResponse(id: id, result: result, data: data)
            }
        } catch {
            logger.info("moblink-streamer: Failed to process message with error \(error)")
            webSocket.connection.cancel()
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
            guard case let .status(batteryPercentage: batteryPercentage) = response else {
                return
            }
            self.batteryPercentage = batteryPercentage
        } onError: { error in
            logger.info("moblink-streamer: Status failed with \(error)")
        }
    }

    private func startTunnelInternal() {
        guard identified, let address, let port else {
            return
        }
        reportTunnelRemoved()
        executeStartTunnel(address: address, port: port) { id, name, port in
            switch self.webSocket.connection.endpoint {
            case let .hostPort(host: host, port: _):
                let endpoint = NWEndpoint.hostPort(
                    host: host,
                    port: NWEndpoint.Port(integerLiteral: port)
                )
                self.tunnelEndpoint = endpoint
                self.streamer?.delegate?.moblinkStreamerTunnelAdded(endpoint: endpoint, relayId: id, relayName: name)
            default:
                logger.info("moblink-streamer: Missing relay host")
            }
        }
    }

    private func reportTunnelRemoved() {
        if let tunnelEndpoint {
            streamer?.delegate?.moblinkStreamerTunnelRemoved(endpoint: tunnelEndpoint)
        }
        tunnelEndpoint = nil
    }

    private func executeStartTunnel(address: String, port: UInt16,
                                    onSuccess: @escaping (UUID, String, UInt16) -> Void)
    {
        logger.info("moblink-streamer: Starting tunnel to destination \(address):\(port)")
        performRequest(data: .startTunnel(address: address, port: port)) { response in
            guard case let .startTunnel(port: port) = response else {
                return
            }
            onSuccess(self.relayId, self.name, port)
        } onError: { error in
            logger.info("moblink-streamer: Start tunnel failed with \(error)")
        }
    }

    private func handleIdentify(relayId: UUID, name: String, authentication: String) throws {
        if authentication == remoteControlHashPassword(
            challenge: challenge,
            salt: salt,
            password: password
        ) {
            self.relayId = relayId
            self.name = name
            identified = true
            send(message: .identified(result: .ok))
            startTunnelInternal()
            updateStatus()
        } else {
            send(message: .identified(result: .wrongPassword))
            throw "Relay sent wrong password"
        }
    }

    private func handleResponse(id: Int, result: MoblinkResult, data: MoblinkResponse?) throws {
        guard identified else {
            throw "Streamer not identified"
        }
        guard let request = requests[id] else {
            logger.info("moblink-streamer: Unexpected id in response")
            return
        }
        switch result {
        case .ok:
            request.onSuccess(data)
        case .wrongPassword:
            request.onError("Wrong password")
        case .notIdentified:
            logger.info("moblink-streamer: Not identified")
        case .alreadyIdentified:
            logger.info("moblink-streamer: Already identified")
        case .unknownRequest:
            logger.info("moblink-streamer: Unknown request")
        }
    }

    private func performRequest(
        data: MoblinkRequest,
        onSuccess: @escaping (MoblinkResponse?) -> Void,
        onError: @escaping (String) -> Void
    ) {
        let id = getNextId()
        requests[id] = RequestResponse(onSuccess: onSuccess, onError: onError)
        send(message: .request(id: id, data: data))
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
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "context", metadata: [metadata])
        webSocket.connection.send(content: text.data(using: .utf8),
                                  contentContext: context,
                                  isComplete: true,
                                  completion: .idempotent)
    }
}

class MoblinkStreamer: NSObject {
    private let port: UInt16
    private let password: String
    private var server: NWListener?
    var connectionErrorMessage = ""
    private var retryStartTimer = SimpleTimer(queue: .main)
    fileprivate weak var delegate: (any MoblinkStreamerDelegate)?
    private var relays: [Relay] = []
    private var destinationAddress: String?
    private var destinationPort: UInt16?
    @AppStorage("moblinkServerId") var id = ""

    init(port: UInt16, password: String) {
        self.port = port
        self.password = password
        super.init()
        if id.isEmpty {
            id = UUID().uuidString
        }
    }

    func start(delegate: MoblinkStreamerDelegate) {
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

    func getStatuses() -> [(String, Int?)] {
        return relays.sorted(by: { first, second in first.name < second.name }).map { ($0.name, $0.batteryPercentage) }
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
                name: id,
                type: moblinkBonjourType,
                domain: moblinkBonjourDomain,
                txtRecord: NWTXTRecord(["name": UIDevice.current.name])
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
        let webSocket = NWConnectionWithId(connection: connection)
        connection.start(queue: .main)
        receivePacket(webSocket: webSocket)
        let relay = Relay(webSocket: webSocket, password: password, streamer: self)
        relay.start()
        relays.append(relay)
        guard let destinationAddress, let destinationPort else {
            return
        }
        relay.startTunnel(address: destinationAddress, port: destinationPort)
    }

    private func handleDisconnected(webSocket: NWConnectionWithId) {
        logger.debug("moblink-streamer: Relay disconnected")
        if let relay = relays.first(where: { $0.webSocket == webSocket }) {
            relay.stop()
        }
        relays.removeAll(where: { $0.webSocket == webSocket })
    }

    private func receivePacket(webSocket: NWConnectionWithId) {
        webSocket.connection.receiveMessage { data, context, _, _ in
            if let data, !data.isEmpty {
                if context?.webSocketOperation() == .text {
                    self.handleMessage(webSocket: webSocket, packet: data)
                }
                self.receivePacket(webSocket: webSocket)
            } else {
                self.handleDisconnected(webSocket: webSocket)
            }
        }
    }

    private func handleMessage(webSocket: NWConnectionWithId, packet: Data) {
        if let text = String(bytes: packet, encoding: .utf8) {
            guard let relay = relays.first(where: { $0.webSocket == webSocket }) else {
                return
            }
            relay.handleStringMessage(message: text)
        }
    }
}
