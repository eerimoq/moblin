import Foundation
import Network

class RemoteConnection {
    private var queue: DispatchQueue
    private var type: NWInterface.InterfaceType?
    private var connection: NWConnection? {
        didSet {
            oldValue?.viabilityUpdateHandler = nil
            oldValue?.stateUpdateHandler = nil
            oldValue?.forceCancel()
        }
    }

    var typeString: String
    var packetHandler: ((_ packet: Data) -> Void)?

    init(queue: DispatchQueue, type: NWInterface.InterfaceType?) {
        self.queue = queue
        self.type = type
        if let type {
            typeString = "\(type)"
        } else {
            typeString = "any"
        }
    }

    func start(host: String, port: UInt16) {
        let options = NWProtocolUDP.Options()
        let params = NWParameters(dtls: .none, udp: options)
        if let type {
            params.requiredInterfaceType = type
        }
        params.prohibitExpensivePaths = false
        connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: port),
            using: params
        )
        connection!.viabilityUpdateHandler = handleViabilityChange(to:)
        connection!.stateUpdateHandler = handleStateChange(to:)
        connection!.start(queue: queue)
        receivePacket()
    }

    func stop() {
        connection?.cancel()
        connection = nil
    }

    func score() -> Int {
        guard let connection, connection.state == .ready else {
            return -1
        }
        switch type {
        case .cellular:
            return 1
        case .wifi:
            return 1
        case .wiredEthernet:
            return 1
        case nil:
            return 1
        default:
            return -1
        }
    }

    private func handleViabilityChange(to viability: Bool) {
        logger
            .info(
                "srtla: \(typeString): Connection viability changed to \(viability)"
            )
    }

    private func handleStateChange(to state: NWConnection.State) {
        logger.info("srtla: \(typeString): Connection state changed to \(state)")
    }

    private func receivePacket() {
        guard let connection else {
            return
        }
        connection
            .receive(minimumIncompleteLength: 1,
                     maximumLength: 4096)
        { data, _, _, error in
            if let data, !data.isEmpty {
                // logger.debug("srtla: \(self.typeString): Receive \(data)")
                if let packetHandler = self.packetHandler {
                    packetHandler(data)
                } else {
                    logger
                        .warning("srtla: \(self.typeString): Discarding packet.")
                }
            }
            if let error {
                logger.warning("srtla: \(self.typeString): Receive \(error)")
                return
            }
            self.receivePacket()
        }
    }

    func sendPacket(packet: Data) {
        guard let connection else {
            logger
                .warning("srtla: \(typeString): Dropping packet. No connection.")
            return
        }
        connection.send(content: packet, completion: .contentProcessed { error in
            if let error {
                logger
                    .error(
                        "srtla: \(self.typeString): Remote send error: \(error)"
                    )
            } else {
                // logger.debug("srtla: \(self.typeString): Sent \(packet)")
            }
        })
    }
}
