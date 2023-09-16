import Foundation
import Network

class LocalListener {
    private var queue: DispatchQueue
    private var listener: NWListener!
    private var connection: NWConnection?
    var packetHandler: ((_ packet: Data) -> Void)?
    private weak var delegate: (any SrtlaDelegate)?

    init(queue: DispatchQueue, delegate: SrtlaDelegate) {
        self.queue = queue
        self.delegate = delegate
    }

    func start() {
        do {
            let options = NWProtocolUDP.Options()
            let parameters = NWParameters(dtls: .none, udp: options)
            parameters.acceptLocalOnly = true
            listener = try NWListener(using: parameters)
        } catch {
            logger.error("srtla: local: Failed to create listener with error \(error)")
            return
        }
        listener.stateUpdateHandler = handleListenerStateChange(to:)
        listener.newConnectionHandler = handleNewListenerConnection(connection:)
        listener.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
    }

    private func handleListenerStateChange(to state: NWListener.State) {
        switch state {
        case .setup:
            break
        case .ready:
            let port = listener.port!.rawValue
            logger.info("srtla: local: Listener ready at port \(port)")
            delegate?.listenerReady(port: port)
        default:
            delegate?.listenerError()
        }
    }

    func handleNewListenerConnection(connection: NWConnection) {
        self.connection = connection
        logger.info("srtla: local: New connection \(connection.debugDescription)")
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                logger.info("srtla: local: Connection ready")
            case let .failed(error):
                logger.info("srtla: local: Connection failed with error \(error)")
            case .cancelled:
                logger.info("srtla: local: Connection cancelled")
            default:
                break
            }
        }
        connection.start(queue: queue)
        receivePacket()
    }

    private func receivePacket() {
        guard let connection else {
            return
        }
        connection
            .receive(minimumIncompleteLength: 1,
                     maximumLength: 32768)
        { data, _, _, error in
            if let data, !data.isEmpty {
                // logger.debug("srtla: local: Received \(data)")
                if let packetHandler = self.packetHandler {
                    packetHandler(data)
                } else {
                    logger.warning("srtla: local: Discarding local packet.")
                }
            }
            if let error {
                logger.info("srtla: local: Local error \(error)")
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
            if let error {
                logger.warning("srtla: local: Local send error: \(error)")
            }
        })
    }
}
