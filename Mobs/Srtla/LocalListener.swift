import Foundation
import Network

class LocalListener {
    private var queue: DispatchQueue
    private var listener: NWListener!
    private var connection: NWConnection?
    var packetHandler: ((_ packet: Data) -> Void)?
    var onReady: ((_ port: UInt16) -> Void)?
    var onError: (() -> Void)?

    init(queue: DispatchQueue) {
        self.queue = queue
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
        listener = nil
        connection?.cancel()
        connection = nil
    }

    private func handleListenerStateChange(to state: NWListener.State) {
        switch state {
        case .setup:
            break
        case .ready:
            onReady?(listener.port!.rawValue)
        default:
            onError?()
        }
    }

    func handleNewListenerConnection(connection: NWConnection) {
        self.connection = connection
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
