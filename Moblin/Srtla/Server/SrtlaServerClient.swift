import Foundation
import Network

class SrtlaServerClient {
    private var connections: [SrtlaServerClientConnection] = []

    init() {
        logger.info("srtla-server-client: Created. Should connect to SRT server.")
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
}

extension SrtlaServerClient: SrtlaServerClientConnectionDelegate {
    func handleSrtPacket(packet: Data) {
        logger.info("srtla-server-client: Got SRT packet \(packet)")
    }
}
