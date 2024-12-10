import AVFAudio
import CoreMedia
import Foundation
import Network

let rtmpServerDispatchQueue = DispatchQueue(label: "com.eerimoq.rtmp-server")
let rtmpServerApp = "/live"

struct RtmpServerStats {
    var total: UInt64
    var speed: UInt64
}

struct RtmpServerClientInfo {
    var audioSamplesPerSecond: Double
    var videoFps: Double
}

protocol RtmpServerDelegate: AnyObject {
    func rtmpServerOnPublishStart(streamKey: String)
    func rtmpServerOnPublishStop(streamKey: String)
    func rtmpServerOnVideoBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer)
    func rtmpServerOnAudioBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer)
    func rtmpServerSetTargetLatencies(
        cameraId: UUID,
        _ videoTargetLatency: Double,
        _ audioTargetLatency: Double
    )
}

class RtmpServer {
    private var listener: NWListener!
    private var clients: [RtmpServerClient]
    weak var delegate: (any RtmpServerDelegate)?
    var settings: SettingsRtmpServer
    private var periodicTimer = SimpleTimer(queue: rtmpServerDispatchQueue)
    var totalBytesReceived: UInt64 = 0
    private var prevTotalBytesReceived: UInt64 = 0

    init(settings: SettingsRtmpServer) {
        self.settings = settings
        clients = []
    }

    func start() {
        rtmpServerDispatchQueue.async {
            self.setupPeriodicTimer()
            self.setupListener()
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
            self.periodicTimer.stop()
        }
    }

    func isStreamConnected(streamKey: String) -> Bool {
        return rtmpServerDispatchQueue.sync {
            clients.contains(where: { client in
                client.streamKey == streamKey
            })
        }
    }

    func streamInfo(streamKey: String) -> RtmpServerClientInfo? {
        return rtmpServerDispatchQueue.sync {
            clients.first(where: { client in
                client.streamKey == streamKey
            })?.getInfo()
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

    private func setupListener() {
        let options = NWProtocolTCP.Options()
        // options.noDelay = true
        let parameters = NWParameters(tls: nil, tcp: options)
        parameters.requiredLocalEndpoint = .hostPort(
            host: .ipv4(.any),
            port: NWEndpoint.Port(rawValue: settings.port) ?? 1935
        )
        parameters.allowLocalEndpointReuse = true
        do {
            listener = try NWListener(using: parameters)
        } catch {
            logger.error("rtmp-server: Failed to create listener with error \(error)")
            return
        }
        listener.stateUpdateHandler = handleListenerStateChange(to:)
        listener.newConnectionHandler = handleNewListenerConnection(connection:)
        listener.start(queue: rtmpServerDispatchQueue)
    }

    private func setupPeriodicTimer() {
        periodicTimer.startPeriodic(interval: 3) {
            self.cleanupClients()
            switch self.listener.state {
            case .failed:
                self.setupListener()
            default:
                break
            }
        }
    }

    private func cleanupClients() {
        var clientsToRemove: [RtmpServerClient] = []
        for client in clients where client.latestReceiveTime.duration(to: .now) > .seconds(10) {
            clientsToRemove.append(client)
        }
        for client in clientsToRemove {
            handleClientDisconnected(client: client, reason: "Receive timeout")
        }
    }

    private func handleListenerStateChange(to state: NWListener.State) {
        logger.info("rtmp-server: State change to \(state)")
        switch state {
        case .ready:
            if let port = listener.port {
                logger.info("rtmp-server: Listening on port \(port.rawValue)")
            }
        default:
            break
        }
    }

    private func handleNewListenerConnection(connection: NWConnection) {
        logger.info("rtmp-server: Client TCP connected")
        let client = RtmpServerClient(server: self, connection: connection)
        client.start()
        clients.append(client)
    }

    func handleClientConnected(client: RtmpServerClient) {
        var newClients: [RtmpServerClient] = []
        for aClient in clients {
            if aClient !== client, aClient.streamKey == client.streamKey {
                delegate?.rtmpServerOnPublishStop(streamKey: client.streamKey)
                aClient.stop(reason: "Same stream key")
            } else {
                newClients.append(aClient)
            }
        }
        clients = newClients
        delegate?.rtmpServerOnPublishStart(streamKey: client.streamKey)
        logNumberOfClients()
    }

    func handleClientDisconnected(client: RtmpServerClient, reason: String) {
        if !client.streamKey.isEmpty {
            delegate?.rtmpServerOnPublishStop(streamKey: client.streamKey)
        }
        client.stop(reason: reason)
        clients.removeAll { c in
            c === client
        }
        logNumberOfClients()
    }

    private func logNumberOfClients() {
        logger.info("rtmp-server: Number of clients: \(clients.count)")
    }
}
