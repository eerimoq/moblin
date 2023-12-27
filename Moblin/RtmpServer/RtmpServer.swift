import CoreMedia
import Foundation
import HaishinKit
import Network

let rtmpServerDispatchQueue = DispatchQueue(label: "com.eerimoq.rtmp-server")

class RtmpServer {
    private var listener: NWListener!
    private var clients: [RtmpServerClient]
    private var onListening: (UInt16) -> Void
    private var onPublishStart: (String) -> Void
    private var onPublishStop: (String) -> Void
    private var onFrame: (String, CMSampleBuffer) -> Void

    init(
        onListening: @escaping (UInt16) -> Void,
        onPublishStart: @escaping (String) -> Void,
        onPublishStop: @escaping (String) -> Void,
        onFrame: @escaping (String, CMSampleBuffer) -> Void
    ) {
        self.onListening = onListening
        self.onPublishStart = onPublishStart
        self.onPublishStop = onPublishStop
        self.onFrame = onFrame
        clients = []
    }

    func start(port: UInt16) {
        rtmpServerDispatchQueue.async {
            do {
                let options = NWProtocolTCP.Options()
                let parameters = NWParameters(tls: nil, tcp: options)
                parameters.requiredLocalEndpoint = .hostPort(
                    host: .ipv4(.any),
                    port: NWEndpoint.Port(rawValue: port) ?? 1935
                )
                parameters.allowLocalEndpointReuse = true
                self.listener = try NWListener(using: parameters)
            } catch {
                logger.error("rtmp-server: Failed to create listener with error \(error)")
                return
            }
            self.listener.stateUpdateHandler = self.handleListenerStateChange(to:)
            self.listener.newConnectionHandler = self.handleNewListenerConnection(connection:)
            self.listener.start(queue: rtmpServerDispatchQueue)
        }
    }

    func stop() {
        rtmpServerDispatchQueue.async {
            for client in self.clients {
                client.stop()
            }
            self.clients.removeAll()
            self.listener?.cancel()
            self.listener = nil
        }
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

    private func handleClientDisconnected(client: RtmpServerClient) {
        client.stop()
        clients.removeAll { c in
            c === client
        }
        logNumberOfClients()
        onPublishStop("test")
    }

    private func handleNewListenerConnection(connection: NWConnection) {
        let client = RtmpServerClient(connection: connection)
        client.start(onDisconnected: handleClientDisconnected, onFrame: onFrame)
        clients.append(client)
        logNumberOfClients()
        onPublishStart("test")
    }

    private func logNumberOfClients() {
        logger.info("rtmp-server: Number of clients: \(clients.count)")
    }
}
