import Foundation
import Network

class SrtlaServerClient {
    private var connections: [SrtlaServerClientConnection] = []

    init() {
        logger.info("srtla-server-client: Created")
    }

    func addConnection(connection: NWConnection) {
        connections.append(.init(connection: connection))
        logger.info("srtla-server-client: Using \(connections.count) connection(s)")
    }
}
