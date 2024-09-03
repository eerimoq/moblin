// SRTLA is a bonding protocol on top of SRT.
// Designed by rationalsa for the BELABOX projecct.
// https://github.com/BELABOX/srtla

import AVFoundation
import Foundation
import libsrt
import Network

struct SrtlaServerStats {
    var total: UInt64
    var speed: UInt64
}

let srtlaServerQueue = DispatchQueue(label: "com.eerimoq.srtla-server", qos: .userInitiated)
private let periodicTimerTimeout = 3.0

protocol SrtlaServerDelegate: AnyObject {
    func srtlaServerOnClientStart(streamId: String)
    func srtlaServerOnClientStop(streamId: String)
    func srtlaServerOnVideoBuffer(streamId: String, sampleBuffer: CMSampleBuffer)
    func srtlaServerOnAudioBuffer(streamId: String, sampleBuffer: CMSampleBuffer)
}

class SrtlaServer {
    private var listener: NWListener?
    private var clients: [Data: SrtlaServerClient] = [:]
    var settings: SettingsSrtlaServer
    private var srtServer: SrtServer
    weak var delegate: (any SrtlaServerDelegate)?
    private var periodicTimer: DispatchSourceTimer?
    private var prevTotalBytesReceived: UInt64 = 0
    var totalBytesReceived: Atomic<UInt64> = .init(0)
    private var numberOfClients: Atomic<Int> = .init(0)

    init(settings: SettingsSrtlaServer) {
        self.settings = settings.clone()
        srtServer = SrtServer()
        srtServer.srtlaServer = self
    }

    func start() {
        srtlaServerQueue.async {
            self.srtServer.start()
            self.startListener()
            self.startPeriodicTimer()
        }
    }

    func stop() {
        srtlaServerQueue.async {
            self.stopPeriodicTimer()
            self.stopListener()
            self.srtServer.stop()
        }
    }

    func isStreamConnected(streamId: String) -> Bool {
        return srtServer.acceptedStreamId.value == streamId
    }

    func updateStats() -> SrtlaServerStats {
        let totalBytesReceived = totalBytesReceived.value
        let speed = totalBytesReceived - prevTotalBytesReceived
        prevTotalBytesReceived = totalBytesReceived
        return SrtlaServerStats(total: totalBytesReceived, speed: speed)
    }

    func getNumberOfClients() -> Int {
        return numberOfClients.value
    }

    func clientConnected(streamId: String) {
        numberOfClients.mutate { $0 += 1 }
        delegate?.srtlaServerOnClientStart(streamId: streamId)
    }

    func clientDisconnected(streamId: String) {
        delegate?.srtlaServerOnClientStop(streamId: streamId)
        numberOfClients.mutate { $0 -= 1 }
    }

    private func startPeriodicTimer() {
        periodicTimer = DispatchSource.makeTimerSource(queue: srtlaServerQueue)
        periodicTimer!.schedule(deadline: .now() + periodicTimerTimeout, repeating: periodicTimerTimeout)
        periodicTimer!.setEventHandler { [weak self] in
            self?.handlePeriodicTimer()
        }
        periodicTimer!.activate()
    }

    private func stopPeriodicTimer() {
        periodicTimer?.cancel()
        periodicTimer = nil
    }

    private func handlePeriodicTimer() {
        var groupIdsToRemove: [Data] = []
        for (groupId, client) in clients where client.handlePeriodicTimer() {
            client.stop()
            groupIdsToRemove.append(groupId)
            logger.info("srtla-server: Removed client")
        }
        for groupId in groupIdsToRemove {
            clients.removeValue(forKey: groupId)
        }
    }

    private func startListener() {
        logger.info("srtla-server: Setup listener")
        guard let srtlaPort = NWEndpoint.Port(rawValue: settings.srtlaPort) else {
            logger.error("srtla-server: Bad listener port \(settings.srtlaPort)")
            return
        }
        let parameters = NWParameters(dtls: .none, udp: .init())
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.any), port: srtlaPort)
        parameters.allowLocalEndpointReuse = true
        do {
            listener = try NWListener(using: parameters)
        } catch {
            logger.error("srtla-server: Failed to create listener with error \(error)")
            return
        }
        listener?.stateUpdateHandler = handleListenerStateChange(to:)
        listener?.newConnectionHandler = handleNewListenerConnection(connection:)
        listener?.start(queue: srtlaServerQueue)
    }

    private func stopListener() {
        listener?.cancel()
        listener = nil
    }

    private func handleListenerStateChange(to state: NWListener.State) {
        logger.info("srtla-server: State change to \(state)")
        switch state {
        case .ready:
            logger.info("srtla-server: Listening on port \(listener?.port?.rawValue ?? 0)")
        default:
            break
        }
    }

    private func handleNewListenerConnection(connection: NWConnection) {
        logger.info("srtla-server: Client \(connection.endpoint) connected")
        connection.start(queue: srtlaDispatchQueue)
        receivePacket(connection: connection)
    }

    private func receivePacket(connection: NWConnection) {
        connection.receiveMessage { data, _, _, error in
            var clientAsReceiver = false
            if let data, !data.isEmpty {
                clientAsReceiver = self.handlePacket(connection: connection, packet: data)
            }
            if let error {
                logger.info("srtla-server: Error \(error)")
                return
            }
            if !clientAsReceiver {
                self.receivePacket(connection: connection)
            }
        }
    }

    private func handlePacket(connection: NWConnection, packet: Data) -> Bool {
        guard packet.count >= srtControlTypeSize else {
            logger.error("srtla-server: Packet too short (\(packet.count).")
            return false
        }
        if !isDataPacket(packet: packet) {
            return handleControlPacket(connection: connection, packet: packet)
        }
        return false
    }

    private func handleControlPacket(connection: NWConnection, packet: Data) -> Bool {
        let type = getControlPacketType(packet: packet)
        if let type = SrtlaPacketType(rawValue: type) {
            return handleSrtlaControlPacket(connection: connection, type: type, packet: packet)
        }
        return false
    }

    private func handleSrtlaControlPacket(connection: NWConnection, type: SrtlaPacketType,
                                          packet: Data) -> Bool
    {
        switch type {
        case .reg1:
            handleSrtlaReg1(connection: connection, packet: packet)
        case .reg2:
            return handleSrtlaReg2(connection: connection, packet: packet)
        default:
            logger.info("srtla-server: Discarding srtla control packet \(type)")
        }
        return false
    }

    private func handleSrtlaReg1(connection: NWConnection, packet: Data) {
        logger.info("srtla-server: Got reg 1 (create group)")
        guard packet.count == 258 else {
            logger.warning("srtla-server: Wrong reg 1 packet length \(packet.count)")
            return
        }
        let groupId = packet[srtControlTypeSize ..< srtControlTypeSize + 128] + Data.random(length: 128)
        guard clients[groupId] == nil else {
            return
        }
        clients[groupId] = SrtlaServerClient(srtPort: settings.srtPort)
        sendSrtlaReg2(connection: connection, groupId: groupId)
    }

    private func handleSrtlaReg2(connection: NWConnection, packet: Data) -> Bool {
        logger.info("srtla-server: Got reg 2 (register connection)")
        guard packet.count == 258 else {
            logger.warning("srtla-server: Wrong reg 2 packet length \(packet.count)")
            return false
        }
        let groupId = packet[srtControlTypeSize...]
        guard let client = clients[groupId] else {
            logger.info("srtla-server: Unknown group id in reg 2 packet.")
            sendSrtlaNgp(connection: connection)
            return false
        }
        client.addConnection(connection: connection)
        sendSrtlaReg3(connection: connection)
        return true
    }

    private func sendSrtlaReg2(connection: NWConnection, groupId: Data) {
        logger.info("srtla-server: Sending reg 2 (group created)")
        var packet = createSrtlaPacket(type: .reg2, length: 258)
        packet[srtControlTypeSize...] = groupId
        sendPacket(connection: connection, packet: packet)
    }

    private func sendSrtlaReg3(connection: NWConnection) {
        logger.info("srtla-server: Sending reg 3 (connection registered)")
        let packet = createSrtlaPacket(type: .reg3, length: srtControlTypeSize)
        sendPacket(connection: connection, packet: packet)
    }

    private func sendSrtlaNgp(connection: NWConnection) {
        logger.info("srtla-server: Sending ngp (no group)")
        let packet = createSrtlaPacket(type: .regNgp, length: srtControlTypeSize)
        sendPacket(connection: connection, packet: packet)
    }

    private func sendPacket(connection: NWConnection, packet: Data) {
        connection.send(content: packet, completion: .contentProcessed { _ in })
    }
}
