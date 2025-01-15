import Foundation
import Network
import Rist

private let ristQueue = DispatchQueue(label: "com.eerimoq.Moblin.rist")
private let weigthTargetBitrate: UInt32 = 10_000_000

private enum RistPeerState {
    case connecting
    case connected
    case disconnected
}

private class RistRemotePeer: AdaptiveBitrateDelegate {
    let interfaceName: String
    let relayEndpoint: NWEndpoint?
    let peer: RistPeer
    var stats: RistSenderStats?
    var adaptiveWeight: AdaptiveBitrateRistExperiment?
    private var state: RistPeerState = .connecting
    private var connectingTimer = SimpleTimer(queue: ristQueue)
    weak var stream: RistStream?

    init(interfaceName: String, relayEndpoint: NWEndpoint?, peer: RistPeer, stream: RistStream) {
        self.interfaceName = interfaceName
        self.relayEndpoint = relayEndpoint
        self.peer = peer
        self.stream = stream
        adaptiveWeight = nil
        adaptiveWeight = AdaptiveBitrateRistExperiment(targetBitrate: weigthTargetBitrate, delegate: self)
        connectingTimer.startSingleShot(timeout: 5) { [weak self] in
            guard let self else {
                return
            }
            logger.info("rist: Failed to connect to server")
            self.state = .disconnected
            self.stream?.checkDisconnected()
        }
    }

    func setConnected() {
        state = .connected
        stopConnectingTimer()
    }

    func setDisconnected() {
        state = .disconnected
    }

    func isConnected() -> Bool {
        return state == .connected
    }

    func isDisconnected() -> Bool {
        return state == .disconnected
    }

    private func stopConnectingTimer() {
        connectingTimer.stop()
    }

    deinit {
        stopConnectingTimer()
    }
}

extension RistRemotePeer {
    func adaptiveBitrateSetVideoStreamBitrate(bitrate _: UInt32) {}
}

private enum RistStreamState {
    case connecting
    case connected
    case disconnected
}

protocol RistStreamDelegate: AnyObject {
    func ristStreamOnConnected()
    func ristStreamOnDisconnected()
    func ristStreamRelayDestinationAddress(address: String, port: UInt16)
}

class RistStream: NetStream {
    private var context: RistContext?
    private var peers: [RistRemotePeer] = []
    private let writer = MpegTsWriter(timecodesEnabled: false)
    private var networkPathMonitor: NWPathMonitor?
    private var bonding: Bool = false
    private var url: String = ""
    private var state: RistStreamState = .connecting
    private weak var ristDelegate: (any RistStreamDelegate)?

    init(deletate: RistStreamDelegate) {
        ristDelegate = deletate
        super.init()
        writer.delegate = self
    }

    func start(url: String, bonding: Bool) {
        ristQueue.async {
            self.startInner(url: url, bonding: bonding)
        }
    }

    func stop() {
        ristQueue.async {
            self.stopInner()
        }
    }

    func addMoblink(endpoint: NWEndpoint, id: UUID, name: String) {
        ristQueue.async {
            self.addRelayInner(endpoint: endpoint, id: id, name: name)
        }
    }

    func removeMoblink(endpoint: NWEndpoint) {
        ristQueue.async {
            self.removeRelayInner(endpoint: endpoint)
        }
    }

    func getSpeed() -> UInt64 {
        var totalBandwidth: UInt64 = 0
        ristQueue.sync {
            for peer in peers {
                if let stats = peer.stats {
                    totalBandwidth += stats.bandwidth + stats.retryBandwidth
                }
            }
        }
        return totalBandwidth
    }

    func connectionStatistics() -> [BondingConnection] {
        var connections: [BondingConnection] = []
        ristQueue.sync {
            for peer in peers {
                var connection = BondingConnection(name: peer.interfaceName, usage: 0)
                if let stats = peer.stats {
                    connection.usage = stats.bandwidth + stats.retryBandwidth
                }
                connections.append(connection)
            }
        }
        return connections
    }

    func getStats() -> [RistSenderStats] {
        return ristQueue.sync {
            peers.filter { $0.stats != nil }.map { $0.stats! }
        }
    }

    func updateConnectionsWeights() {
        ristQueue.async {
            self.updateConnectionsWeightsInner()
        }
    }

    private func startInner(url: String, bonding: Bool) {
        state = .connecting
        self.url = url
        self.bonding = bonding
        guard let context = RistContext() else {
            logger.info("rist: Failed to create context")
            return
        }
        context.onStats = handleStats(stats:)
        context.onPeerConnected = handlePeerConnected(peerId:)
        context.onPeerDisconnected = handlePeerDisonnected(peerId:)
        self.context = context
        if bonding {
            networkPathMonitor = .init()
            networkPathMonitor?.pathUpdateHandler = handleNetworkPathUpdate(path:)
            networkPathMonitor?.start(queue: ristQueue)
        } else {
            addPeer(url: url, interfaceName: "")
        }
        if !context.start() {
            logger.info("rist: Failed to start")
            return
        }
        netStreamLockQueue.async {
            self.writer.expectedMedias.insert(.video)
            self.writer.expectedMedias.insert(.audio)
            self.mixer.startEncoding(self.writer)
            self.mixer.startRunning()
            self.writer.startRunning()
        }
        guard let url = URL(string: url), let host = url.host(), let port = url.port else {
            return
        }
        ristDelegate?.ristStreamRelayDestinationAddress(address: host, port: UInt16(port))
    }

    private func stopInner() {
        state = .disconnected
        networkPathMonitor?.cancel()
        networkPathMonitor = nil
        netStreamLockQueue.async {
            self.writer.stopRunning()
            self.mixer.stopEncoding()
        }
        peers.removeAll()
        context = nil
    }

    private func addRelayInner(endpoint: NWEndpoint, id _: UUID, name: String) {
        guard bonding else {
            return
        }
        addPeer(url: makeBondingUrl("rist://\(endpoint)"), interfaceName: name, relayEndpoint: endpoint)
    }

    private func removeRelayInner(endpoint: NWEndpoint) {
        guard bonding else {
            return
        }
        peers.removeAll(where: { $0.relayEndpoint == endpoint })
    }

    private func updateConnectionsWeightsInner() {
        for peer in peers {
            guard let stats = peer.stats, let adaptiveWeight = peer.adaptiveWeight else {
                continue
            }
            adaptiveWeight.update(stats: StreamStats(
                rttMs: Double(stats.rtt),
                packetsInFlight: 10,
                transportBitrate: nil,
                latency: nil,
                mbpsSendRate: nil
            ))
            let weight = max(adaptiveWeight.getCurrentBitrate() / (weigthTargetBitrate / 25), 1)
            logger.debug("rist: peer \(stats.peerId): weight \(weight)")
            peer.peer.setWeight(weight: weight)
        }
    }

    private func handleNetworkPathUpdate(path: NWPath) {
        guard bonding else {
            return
        }
        let interfaceNames = path.availableInterfaces.map { $0.name }
        var removedInterfaceNames: [String] = []
        for peer in peers where peer.relayEndpoint == nil {
            if interfaceNames.contains(peer.interfaceName) {
                continue
            }
            removedInterfaceNames.append(peer.interfaceName)
        }
        for interfaceName in removedInterfaceNames {
            logger.info("rist: Removing peer for interface \(interfaceName)")
            peers.removeAll(where: { $0.interfaceName == interfaceName })
        }
        for interfaceName in interfaceNames {
            if peers.contains(where: { $0.interfaceName == interfaceName }) {
                continue
            }
            addPeer(url: makeBondingUrl(url, interfaceName), interfaceName: interfaceName)
        }
    }

    private func makeBondingUrl(_ url: String, _ interfaceName: String? = nil) -> String? {
        guard let url = URL(string: url) else {
            return nil
        }
        guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        urlComponents.query = url.query
        var queryItems: [URLQueryItem] = urlComponents.queryItems ?? []
        if let interfaceName {
            queryItems.append(URLQueryItem(name: "miface", value: interfaceName))
        }
        queryItems.append(URLQueryItem(name: "weight", value: "1"))
        urlComponents.queryItems = queryItems
        return urlComponents.url?.absoluteString
    }

    private func handleStats(stats: RistStats) {
        ristQueue.async {
            self.handleStatsInner(stats: stats)
        }
    }

    private func handlePeerConnected(peerId: UInt32) {
        ristQueue.async {
            self.handlePeerConnectedInner(peerId: peerId)
        }
    }

    private func handlePeerConnectedInner(peerId: UInt32) {
        logger.info("rist: Peer \(peerId) connected")
        getPeerById(peerId: peerId)?.setConnected()
        checkConnected()
    }

    private func handlePeerDisonnected(peerId: UInt32) {
        ristQueue.async {
            self.handlePeerDisconnectedInner(peerId: peerId)
        }
    }

    private func handlePeerDisconnectedInner(peerId: UInt32) {
        logger.info("rist: Peer \(peerId) disconnected")
        getPeerById(peerId: peerId)?.setDisconnected()
        checkDisconnected()
    }

    private func handleStatsInner(stats: RistStats) {
        logger.debug("""
        rist: peer \(stats.sender.peerId), rtt \(stats.sender.rtt), \
        sent \(stats.sender.sentPackets), received \(stats.sender.receivedPackets), \
        retransmitted \(stats.sender.retransmittedPackets), quality \(stats.sender.quality), \
        bandwidth \(formatBytesPerSecond(speed: Int64(stats.sender.bandwidth))), \
        retry bandwidth \(formatBytesPerSecond(speed: Int64(stats.sender.retryBandwidth)))
        """)
        getPeerById(peerId: stats.sender.peerId)?.stats = stats.sender
    }

    private func addPeer(url: String?, interfaceName: String, relayEndpoint: NWEndpoint? = nil) {
        logger.info("rist: Adding peer for interface \(interfaceName)")
        guard let url, let peer = context?.addPeer(url: url) else {
            logger.info("rist: Failed to add peer")
            return
        }
        peers.append(RistRemotePeer(
            interfaceName: interfaceName,
            relayEndpoint: relayEndpoint,
            peer: peer,
            stream: self
        ))
    }

    private func getPeerById(peerId: UInt32) -> RistRemotePeer? {
        return peers.first(where: { $0.peer.getId() == peerId })
    }

    func checkConnected() {
        guard state == .connecting else {
            return
        }
        for peer in peers where peer.isConnected() {
            state = .connected
            ristDelegate?.ristStreamOnConnected()
            break
        }
    }

    func checkDisconnected() {
        for peer in peers where !peer.isDisconnected() {
            return
        }
        logger.info("rist: All peers disconnected")
        state = .disconnected
        ristDelegate?.ristStreamOnDisconnected()
    }

    private func send(data: Data) {
        _ = context?.send(data: data)
    }

    private func send(dataPointer: UnsafeRawBufferPointer, count: Int) {
        _ = context?.send(dataPointer: dataPointer, count: count)
    }
}

extension RistStream: MpegTsWriterDelegate {
    func writer(_: MpegTsWriter, doOutput data: Data) {
        send(data: data)
    }

    func writer(_: MpegTsWriter, doOutputPointer dataPointer: UnsafeRawBufferPointer, count: Int) {
        send(dataPointer: dataPointer, count: count)
    }
}
