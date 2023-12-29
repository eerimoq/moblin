import CoreMedia
import Foundation
import HaishinKit
import Network

let rtmpServerDispatchQueue = DispatchQueue(label: "com.eerimoq.rtmp-server")
let rtmpApp = "/live"

func rtmpStreamUrl(address: String, port: UInt16, streamKey: String) -> String {
    return "rtmp://\(address):\(port)\(rtmpApp)/\(streamKey)"
}

struct RtmpServerStats {
    var total: UInt64
    var speed: UInt64
}

class RtmpServer {
    private var listener: NWListener!
    private var clients: [RtmpServerClient]
    var onPublishStart: (String) -> Void
    var onPublishStop: (String) -> Void
    var onFrame: (String, CMSampleBuffer) -> Void
    var settings: SettingsRtmpServer
    private var clientsTimeoutTimer: DispatchSourceTimer?
    var totalBytesReceived: UInt64 = 0
    private var prevTotalBytesReceived: UInt64 = 0

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
            self.clientsTimeoutTimer = DispatchSource.makeTimerSource(queue: rtmpServerDispatchQueue)
            self.clientsTimeoutTimer!.schedule(deadline: .now() + 3, repeating: 3)
            self.clientsTimeoutTimer!.setEventHandler {
                let now = Date()
                var clientsToRemove: [RtmpServerClient] = []
                for client in self.clients where client.latestReveiveDate + 10 < now {
                    clientsToRemove.append(client)
                }
                for client in clientsToRemove {
                    self.handleClientDisconnected(client: client, reason: "Receive timeout")
                }
            }
            self.clientsTimeoutTimer!.activate()
        }
    }

    func stop() {
        rtmpServerDispatchQueue.async {
            for client in self.clients {
                client.stop(reason: "Server stop")
            }
            self.clients.removeAll()
            self.listener?.cancel()
            self.listener = nil
            self.clientsTimeoutTimer?.cancel()
            self.clientsTimeoutTimer = nil
        }
    }

    func isStreamConnected(streamKey: String) -> Bool {
        return rtmpServerDispatchQueue.sync {
            clients.contains(where: { client in
                client.streamKey == streamKey
            })
        }
    }

    func updateStats() -> RtmpServerStats {
        return rtmpServerDispatchQueue.sync {
            let speed = totalBytesReceived - prevTotalBytesReceived
            prevTotalBytesReceived = totalBytesReceived
            return RtmpServerStats(total: totalBytesReceived, speed: speed)
        }
    }

    func numberOfClients() -> Int {
        return rtmpServerDispatchQueue.sync {
            clients.count
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
            client.stop(reason: "Client with stream key \(client.streamKey) already connected")
            return
        }
        onPublishStart(client.streamKey)
        logNumberOfClients()
    }

    func handleClientDisconnected(client: RtmpServerClient, reason: String) {
        onPublishStop(client.streamKey)
        client.stop(reason: reason)
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
