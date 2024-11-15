// SRTLA is a bonding protocol on top of SRT.
// Designed by rationalsa for the BELABOX projecct.
// https://github.com/BELABOX/srtla

import Foundation
import Network

private let clientRemoveTimeout = 10.0

private class NakPacket {
    private var sns: [UInt32] = []
    private var latestNakTimestamp: UInt32?
    private var latestNakDestinationSrtSocketId: UInt32?

    func setLatestTimestamp(timestamp: UInt32) {
        latestNakTimestamp = timestamp
    }

    func setLatestNakDestinationSrtSocketId(socketId: UInt32) {
        latestNakDestinationSrtSocketId = socketId
    }

    func add(sn: UInt32) {
        if let index = sns.firstIndex(where: { $0 >= sn }) {
            if sns[index] != sn {
                sns.insert(sn, at: index)
            }
        } else {
            sns.append(sn)
        }
    }

    func removeUpTo(ackSn: UInt32) {
        sns = sns.filter { !isSrtSnAcked(sn: $0, ackSn: ackSn) }
    }

    func remove(sn: UInt32) {
        if let index = sns.firstIndex(where: { $0 == sn }) {
            sns.remove(at: index)
        }
    }

    func pack() -> Data? {
        guard !sns.isEmpty, let latestNakTimestamp, let latestNakDestinationSrtSocketId else {
            return nil
        }
        let writer = ByteArray()
        writer.writeUInt16(SrtPacketType.nak.rawValue | srtControlPacketTypeBit)
        writer.writeUInt16(0)
        writer.writeUInt32(0)
        writer.writeUInt32(latestNakTimestamp)
        writer.writeUInt32(latestNakDestinationSrtSocketId)
        for sn in sns.prefix(1300 / 4) {
            writer.writeUInt32(sn)
        }
        return writer.data
    }
}

class SrtlaServerClient {
    private var localSrtServerConnection: NWConnection?
    private var connections: [SrtlaServerClientConnection] = []
    private var latestConnection: SrtlaServerClientConnection?
    let createdAt: ContinuousClock.Instant = .now
    private var nakPacket = NakPacket()
    private var periodicNakTimer = SimpleTimer(queue: srtlaServerQueue)

    init(srtPort: UInt16) {
        logger.info("srtla-server-client: Creating local SRT server connection.")
        createLocalSrtServerConnection(srtPort: srtPort)
        startPeriodicNakTimer()
    }

    func stop() {
        stopPeriodicNakTimer()
        localSrtServerConnection?.cancel()
        localSrtServerConnection = nil
    }

    private func createLocalSrtServerConnection(srtPort: UInt16) {
        let params = NWParameters(dtls: .none)
        localSrtServerConnection = NWConnection(
            host: .ipv4(.loopback),
            port: .init(integerLiteral: srtPort),
            using: params
        )
        localSrtServerConnection!.stateUpdateHandler = handleStateUpdate(to:)
        localSrtServerConnection!.start(queue: srtlaServerQueue)
        receivePacket()
    }

    private func startPeriodicNakTimer() {
        periodicNakTimer.startPeriodic(interval: 0.1) { [weak self] in
            self?.handlePeriodicNakTimer()
        }
    }

    private func stopPeriodicNakTimer() {
        periodicNakTimer.stop()
    }

    private func handlePeriodicNakTimer() {
        guard let packet = nakPacket.pack() else {
            return
        }
        sendPacketOnLatestConnection(packet: packet)
    }

    private func handleStateUpdate(to state: NWConnection.State) {
        logger.info("srtla-server-client: State change to \(state)")
    }

    private func receivePacket() {
        localSrtServerConnection?.receiveMessage { packet, _, _, error in
            if let packet, !packet.isEmpty {
                self.handlePacketFromLocalSrtServer(packet: packet)
            }
            if let error {
                logger.warning("srtla-server-client: Receive \(error)")
                return
            }
            self.receivePacket()
        }
    }

    func addConnection(connection: NWConnection) {
        guard !connections.contains(where: { $0.connection.endpoint == connection.endpoint }) else {
            logger.info("srtla-server-client: Connection \(connection.endpoint) already registered")
            return
        }
        let connection = SrtlaServerClientConnection(connection: connection)
        connection.delegate = self
        connections.append(connection)
        logger.info("srtla-server-client: Added connection. Using \(connections.count) connection(s)")
    }

    private func handlePacketFromLocalSrtServer(packet: Data) {
        if isSrtDataPacket(packet: packet) {
            sendPacketOnLatestConnection(packet: packet)
        } else {
            switch SrtPacketType(rawValue: getSrtControlPacketType(packet: packet)) {
            case .ack:
                handleAckPacketFromLocalSrtServer(packet: packet)
            case .nak:
                handleNakPacketFromLocalSrtServer(packet: packet)
            default:
                sendPacketOnLatestConnection(packet: packet)
            }
        }
    }

    private func handleAckPacketFromLocalSrtServer(packet: Data) {
        sendPacketOnAllConnections(packet: packet)
        guard packet.count >= 20 else {
            return
        }
        nakPacket.removeUpTo(ackSn: getSrtSequenceNumber(packet: packet[16 ..< 20]))
    }

    private func handleNakPacketFromLocalSrtServer(packet: Data) {
        sendPacketOnAllConnections(packet: packet)
        guard packet.count >= 16 else {
            return
        }
        processSrtNak(packet: packet) { sn in
            nakPacket.add(sn: sn)
        }
        nakPacket.setLatestTimestamp(timestamp: packet.getUInt32Be(offset: 8))
        nakPacket.setLatestNakDestinationSrtSocketId(socketId: packet.getUInt32Be(offset: 12))
    }

    private func sendPacketOnLatestConnection(packet: Data) {
        latestConnection?.sendPacket(packet: packet)
    }

    private func sendPacketOnAllConnections(packet: Data) {
        for connection in connections {
            connection.sendPacket(packet: packet)
        }
    }

    func handlePeriodicTimer() -> Bool {
        let now = ContinuousClock.now
        var index = 0
        while index < connections.count {
            let connection = connections[index]
            if connection.isActive(now: now) {
                index += 1
            } else {
                connection.stop()
                connections.remove(at: index)
                logger
                    .info("srtla-server-client: Removed connection. Using \(connections.count) connection(s)")
            }
        }
        return connections.isEmpty && createdAt.duration(to: now) > .seconds(clientRemoveTimeout)
    }
}

extension SrtlaServerClient: SrtlaServerClientConnectionDelegate {
    func handlePacketFromSrtClient(_ connection: SrtlaServerClientConnection, packet: Data) {
        if isSrtDataPacket(packet: packet) {
            nakPacket.remove(sn: getSrtSequenceNumber(packet: packet))
        }
        latestConnection = connection
        localSrtServerConnection?.send(content: packet, completion: .contentProcessed { _ in })
    }
}
