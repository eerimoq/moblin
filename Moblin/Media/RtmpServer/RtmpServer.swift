import AVFAudio
import CoreMedia
import Foundation
import Network

let rtmpServerDispatchQueue = DispatchQueue(label: "com.eerimoq.rtmp-server")
let rtmpServerApp = "/live"

protocol RtmpServerDelegate: AnyObject {
    func rtmpServerOnPublishStart(streamKey: String)
    func rtmpServerOnPublishStop(streamKey: String, reason: String)
    func rtmpServerOnVideoBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer)
    func rtmpServerOnAudioBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer)
    func rtmpServerSetTargetLatencies(
        cameraId: UUID,
        _ videoTargetLatency: Double,
        _ audioTargetLatency: Double
    )
}

class RtmpServer: @unchecked Sendable {
    private var listener: NWListener?
    private var clients: [RtmpServerClient]
    let delegate: any RtmpServerDelegate
    var settings: SettingsRtmpServer
    private let softwareDecoding: Bool
    private var periodicTimer = SimpleTimer(queue: rtmpServerDispatchQueue)
    let bitrateStats: Atomic<BitrateStats> = .init(BitrateStats())
    private var numberOfClients: Atomic<Int> = .init(0)
    private var connectedStreamKeys: Atomic<[String]> = .init([])

    init(settings: SettingsRtmpServer, softwareDecoding: Bool, delegate: any RtmpServerDelegate) {
        self.settings = settings
        self.softwareDecoding = softwareDecoding
        self.delegate = delegate
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
            self.clientsChanged()
            self.listener?.stateUpdateHandler = nil
            self.listener?.newConnectionHandler = nil
            self.listener?.cancel()
            self.listener = nil
            self.periodicTimer.stop()
        }
    }

    func isStreamConnected(streamKey: String) -> Bool {
        connectedStreamKeys.value.contains(streamKey)
    }

    func updateStats() -> BitrateStatsInstant {
        nonisolated(unsafe)
        var result: BitrateStatsInstant?
        bitrateStats.mutate {
            result = $0.update()
        }
        return result!
    }

    func getNumberOfClients() -> Int {
        numberOfClients.value
    }

    private func setupListener() {
        let options = NWProtocolTCP.Options()
        // options.noDelay = true
        let parameters = NWParameters(tls: nil, tcp: options)
        parameters.requiredLocalEndpoint = .hostPort(
            host: .ipv4(.any),
            port: .init(rawValue: settings.port) ?? .init(integerLiteral: DefaultTcpPorts.rtmpServer)
        )
        parameters.allowLocalEndpointReuse = true
        do {
            listener = try NWListener(using: parameters)
        } catch {
            logger.info("rtmp-server: Failed to create listener with error \(error)")
            return
        }
        listener?.stateUpdateHandler = handleListenerStateChange(to:)
        listener?.newConnectionHandler = handleNewListenerConnection(connection:)
        listener?.start(queue: rtmpServerDispatchQueue)
    }

    private func setupPeriodicTimer() {
        periodicTimer.startPeriodic(interval: 3) {
            self.cleanupClients()
            switch self.listener?.state {
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
            if let port = listener?.port {
                logger.info("rtmp-server: Listening on port \(port.rawValue)")
            }
        default:
            break
        }
    }

    private func handleNewListenerConnection(connection: NWConnection) {
        logger.info("rtmp-server: Client TCP connected")
        let client = RtmpServerClient(server: self,
                                      connection: connection,
                                      softwareDecoding: softwareDecoding)
        client.start()
        clients.append(client)
        clientsChanged()
    }

    func handleClientConnected(client: RtmpServerClient) {
        var newClients: [RtmpServerClient] = []
        for aClient in clients {
            if aClient !== client, aClient.streamKey == client.streamKey {
                let reason = "Same stream key"
                delegate.rtmpServerOnPublishStop(streamKey: client.streamKey, reason: reason)
                aClient.stop(reason: reason)
            } else {
                newClients.append(aClient)
            }
        }
        clients = newClients
        clientsChanged()
        delegate.rtmpServerOnPublishStart(streamKey: client.streamKey)
        logNumberOfClients()
    }

    func handleClientDisconnected(client: RtmpServerClient, reason: String) {
        client.stop(reason: reason)
        clients.removeAll { c in
            c === client
        }
        clientsChanged()
        logNumberOfClients()
        if !client.streamKey.isEmpty {
            delegate.rtmpServerOnPublishStop(streamKey: client.streamKey, reason: reason)
        }
    }

    private func clientsChanged() {
        let count = clients.count
        numberOfClients.mutate { $0 = count }
        let streamKeys = clients.map(\.streamKey).filter { !$0.isEmpty }
        connectedStreamKeys.mutate { $0 = streamKeys }
    }

    private func logNumberOfClients() {
        logger.info("rtmp-server: Number of clients: \(clients.count)")
    }
}
