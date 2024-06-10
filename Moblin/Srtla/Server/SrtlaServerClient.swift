import Foundation
import Network

class SrtlaServerClient {
    private var localSrtServerConnection: NWConnection?
    private var connections: [SrtlaServerClientConnection] = []
    private var latestConnection: SrtlaServerClientConnection?

    init(srtPort: UInt16) {
        logger.info("srtla-server-client: Creating local SRT server connection.")
        createSrtConnection(srtPort: srtPort)
    }

    private func createSrtConnection(srtPort: UInt16) {
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
                self.handlePacketFromSrtServer(packet: packet)
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
        logger.info("srtla-server-client: Using \(connections.count) connection(s)")
    }

    private func handlePacketFromSrtServer(packet: Data) {
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
}

extension SrtlaServerClient: SrtlaServerClientConnectionDelegate {
    func handlePacketFromSrtClient(_ connection: SrtlaServerClientConnection, packet: Data) {
        latestConnection = connection
        localSrtServerConnection?.send(content: packet, completion: .contentProcessed { _ in })
    }
}
