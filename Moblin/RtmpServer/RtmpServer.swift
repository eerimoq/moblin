import CoreMedia
import Foundation
import HaishinKit
import Network

let rtmpServerDispatchQueue = DispatchQueue(label: "com.eerimoq.rtmp-server")

class RtmpServer {
    private var listener: NWListener!
    private var clients: [RtmpServerClient]
    var onPublishStart: (String) -> Void
    var onPublishStop: (String) -> Void
    var onFrame: (String, CMSampleBuffer) -> Void
    var settings: SettingsRtmpServer

    init(settings: SettingsRtmpServer,
         onPublishStart: @escaping (String) -> Void,
         onPublishStop: @escaping (String) -> Void,
         onFrame: @escaping (String, CMSampleBuffer) -> Void)
    {
        self.settings = settings
        self.onPublishStart = onPublishStart
        self.onPublishStop = onPublishStop
        self.onFrame = onFrame
        clients = []
    }

    func start() {
        rtmpServerDispatchQueue.async {
            do {
                let options = NWProtocolTCP.Options()
                let parameters = NWParameters(tls: nil, tcp: options)
                parameters.requiredLocalEndpoint = .hostPort(
                    host: .ipv4(.any),
                    port: NWEndpoint.Port(rawValue: self.settings.port) ?? 1935
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
        default:
            break
        }
    }

    func handleClientConnected(client: RtmpServerClient) {
        guard !clients.filter({ activeClient in
            activeClient !== client
        }).contains(where: { activeClient in
            activeClient.streamKey == client.streamKey
        }) else {
            logger.info("rtmp-server: Client with stream key \(client.streamKey) already connected")
            client.stop()
            return
        }
        onPublishStart(client.streamKey)
        logNumberOfClients()
    }

    func handleClientDisconnected(client: RtmpServerClient) {
        onPublishStop(client.streamKey)
        client.stop()
        clients.removeAll { c in
            c === client
        }
        logNumberOfClients()
    }

    private func handleNewListenerConnection(connection: NWConnection) {
        let client = RtmpServerClient(server: self, connection: connection)
        client.start()
        clients.append(client)
    }

    private func logNumberOfClients() {
        logger.info("rtmp-server: Number of clients: \(clients.count)")
    }
}
