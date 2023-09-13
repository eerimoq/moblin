import Foundation
import Network

class RemoteConnection {
    private var queue: DispatchQueue
    private var type: NWInterface.InterfaceType
    private var connection: NWConnection? {
        didSet {
            oldValue?.viabilityUpdateHandler = nil
            oldValue?.stateUpdateHandler = nil
            oldValue?.forceCancel()
        }
    }
    var packetHandler: ((_ packet: Data) -> Void)?
    
    init(queue: DispatchQueue, type: NWInterface.InterfaceType) {
        self.queue = queue
        self.type = type
    }
    
    func start(host: String, port: UInt16) {
        let options = NWProtocolUDP.Options()
        let params = NWParameters(dtls: .none, udp: options)
        params.requiredInterfaceType = type
        params.prohibitExpensivePaths = false
        connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: port), using: params)
        if let connection = connection {
            connection.viabilityUpdateHandler = handleViabilityChange(to:)
            connection.stateUpdateHandler = handleStateChange(to:)
            connection.start(queue: queue)
            receivePacket()
        }
    }

    func stop() {
        connection?.cancel()
        connection = nil
    }
    
    func score() -> Int {
        guard
            let connection = connection,
            connection.state == .ready else {
            return -1
        }
        return 1
    }
    
    private func handleViabilityChange(to viability: Bool) {
        logger.info("srtla: remote: \(type): Connection viability changed to \(viability)")
    }

    private func handleStateChange(to state: NWConnection.State) {
        logger.info("srtla: remote: \(type): Connection state changed to \(state)")
    }
    
    private func receivePacket() {
        guard let connection else {
            return
        }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isDone, error in
            if let data = data, !data.isEmpty {
                logger.debug("srtla: remote: \(self.type): Receive \(data)")
                if let packetHandler = self.packetHandler {
                    packetHandler(data)
                } else {
                    logger.warning("srtla: remote: \(self.type): Discarding packet.")
                }
            }
            if let error = error {
                logger.warning("srtla: remote: \(self.type): Receive \(error)")
                return
            }
            if isDone {
                logger.info("srtla: remote: \(self.type): Receive done")
                return
            }
            self.receivePacket()
        }
    }
    
    func sendPacket(packet: Data) {
        guard let connection else {
            return
        }
        connection.send(content: packet, completion: .contentProcessed { error in
            if let error = error {
                logger.error("srtla: remote: \(self.type): Remote send error: \(error)")
            } else {
                logger.debug("srtla: remote: Sent \(packet)")
            }
        })
    }
}
