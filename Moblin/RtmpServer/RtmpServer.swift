import Foundation
import HaishinKit
import Network

let rtmpServerDispatchQueue = DispatchQueue(label: "com.eerimoq.rtmp-server")

class RtmpServer {
    private var listener: NWListener!
    private var clients: [RtmpServerClient]
    private var onListening: (UInt16) -> Void

    init(onListening: @escaping (UInt16) -> Void) {
        self.onListening = onListening
        logger.info("rtmp-server: Client connected")
        clients = []
    }

    func start() {
        do {
            let options = NWProtocolTCP.Options()
            let parameters = NWParameters(tls: nil, tcp: options)
            parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(IPv4Address("10.0.0.8")!), port: 1935)
            parameters.allowLocalEndpointReuse = true
            listener = try NWListener(using: parameters)
        } catch {
            logger.error("rtmp-server: Failed to create listener with error \(error)")
            return
        }
        listener.stateUpdateHandler = handleListenerStateChange(to:)
        listener.newConnectionHandler = handleNewListenerConnection(connection:)
        listener.start(queue: rtmpServerDispatchQueue)
    }

    func stop() {
        for client in clients {
            client.stop()
        }
        clients.removeAll()
        listener?.cancel()
        listener = nil
    }

    private func handleListenerStateChange(to state: NWListener.State) {
        logger.info("rtmp-server: State change to \(state)")
        switch state {
        case .setup:
            break
        case .ready:
            logger.info("rtmp-server: Listening on port \(listener.port!.rawValue)")
            onListening(listener.port!.rawValue)
        default:
            break
        }
    }

    private func handleNewListenerConnection(connection: NWConnection) {
        let client = RtmpServerClient(connection: connection)
        client.start()
        clients.append(client)
    }
}
