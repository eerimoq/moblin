// SRTLA is a bonding protocol on top of SRT.
// Designed by rationalsa for the BELABOX projecct.
// https://github.com/BELABOX/srtla

import Foundation
import Network

private let clientRemoveTimeout = 10.0

class SrtlaServerClient {
    private var localSrtServerConnection: NWConnection?
    private var connections: [SrtlaServerClientConnection] = []
    private var latestConnection: SrtlaServerClientConnection?
    let createdAt: ContinuousClock.Instant = .now

    init(srtPort: UInt16) {
        logger.info("srtla-server-client: Creating local SRT server connection.")
        createLocalSrtServerConnection(srtPort: srtPort)
    }

    func stop() {
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
        if !isDataPacket(packet: packet),
           SrtPacketType(rawValue: getControlPacketType(packet: packet)) == .ack
        {
            for connection in connections {
                connection.sendPacket(packet: packet)
            }
        } else {
            latestConnection?.sendPacket(packet: packet)
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
        latestConnection = connection
        localSrtServerConnection?.send(content: packet, completion: .contentProcessed { _ in })
    }
}
