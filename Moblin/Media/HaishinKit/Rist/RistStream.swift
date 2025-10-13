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
    let interfaceType: NWInterface.InterfaceType?
    let relayEndpoint: NWEndpoint?
    let peer: RistPeer
    var stats: RistSenderStats?
    var adaptiveWeight: AdaptiveBitrateRistExperiment?
    private var state: RistPeerState = .connecting
    private var connectingTimer = SimpleTimer(queue: ristQueue)
    weak var stream: RistStream?

    init(interfaceName: String,
         interfaceType: NWInterface.InterfaceType?,
         relayEndpoint: NWEndpoint?,
         peer: RistPeer,
         stream: RistStream)
    {
        self.interfaceName = interfaceName
        self.interfaceType = interfaceType
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

    deinit {
        stopConnectingTimer()
    }

    func bondingConnectionName() -> String {
        switch interfaceType {
        case .cellular:
            return "Cellular"
        case .wifi:
            return "WiFi"
        default:
            return interfaceName
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

class RistStream {
    private var context: RistSenderContext?
    private var peers: [RistRemotePeer] = []
    private let writer: MpegTsWriter
    private var networkPathMonitor: NWPathMonitor?
    private var bonding: Bool = false
    private var url: String = ""
    private var state: RistStreamState = .connecting
    private weak var ristDelegate: (any RistStreamDelegate)?
    private let processor: Processor

    init(processor: Processor, timecodesEnabled: Bool, delegate: RistStreamDelegate) {
        self.processor = processor
        writer = MpegTsWriter(timecodesEnabled: timecodesEnabled, newSrt: false)
        ristDelegate = delegate
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
                var connection = BondingConnection(name: peer.bondingConnectionName(), usage: 0, rtt: nil)
                if let stats = peer.stats {
                    connection.usage = stats.bandwidth + stats.retryBandwidth
                    connection.rtt = Int(stats.rtt)
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

    private func startInner(url: String, bonding: Bool) {
        state = .connecting
        self.url = url
        self.bonding = bonding
        guard let context = RistSenderContext() else {
            logger.info("rist: Failed to create context")
            return
        }
        context.delegate = self
        self.context = context
        if bonding {
            networkPathMonitor = .init()
            networkPathMonitor?.pathUpdateHandler = handleNetworkPathUpdate(path:)
            networkPathMonitor?.start(queue: ristQueue)
        } else {
            addPeer(url: url, interfaceName: "", interfaceType: nil)
        }
        if !context.start() {
            logger.info("rist: Failed to start")
            return
        }
        processorControlQueue.async {
            self.processor.startEncoding(self.writer)
            self.writer.startRunning()
        }
        guard let url = URL(string: url), let host = url.host(), let port = url.port else {
            return
        }
        ristDelegate?.ristStreamRelayDestinationAddress(address: host, port: UInt16(clamping: port))
    }

    private func stopInner() {
        state = .disconnected
        networkPathMonitor?.cancel()
        networkPathMonitor = nil
        processorControlQueue.async {
            self.writer.stopRunning()
            self.processor.stopEncoding(self.writer)
        }
        peers.removeAll()
        context = nil
    }

    private func addRelayInner(endpoint: NWEndpoint, id _: UUID, name: String) {
        guard bonding else {
            return
        }
        addPeer(url: makeBondingUrl("rist://\(endpoint)"),
                interfaceName: name,
                interfaceType: nil,
                relayEndpoint: endpoint)
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
                mbpsSendRate: nil,
                relaxed: nil
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
        let interfaces = path.uniqueAvailableInterfaces()
        var removedInterfaceNames: [String] = []
        for peer in peers where peer.relayEndpoint == nil {
            if interfaces.map({ $0.name }).contains(peer.interfaceName) {
                continue
            }
            removedInterfaceNames.append(peer.interfaceName)
        }
        for interfaceName in removedInterfaceNames {
            logger.info("rist: Removing peer for interface \(interfaceName)")
            peers.removeAll(where: { $0.interfaceName == interfaceName })
        }
        for interface in interfaces {
            if peers.contains(where: { $0.interfaceName == interface.name }) {
                continue
            }
            addPeer(url: makeBondingUrl(url, interface.name),
                    interfaceName: interface.name,
                    interfaceType: interface.type)
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

    private func addPeer(url: String?,
                         interfaceName: String,
                         interfaceType: NWInterface.InterfaceType?,
                         relayEndpoint: NWEndpoint? = nil)
    {
        guard let url, let peer = context?.addPeer(url: url) else {
            logger.info("rist: Failed to add peer")
            return
        }
        peers.append(RistRemotePeer(
            interfaceName: interfaceName,
            interfaceType: interfaceType,
            relayEndpoint: relayEndpoint,
            peer: peer,
            stream: self
        ))
    }

    private func getPeerById(peerId: UInt32) -> RistRemotePeer? {
        return peers.first(where: { $0.peer.getId() == peerId })
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

    func writer(_: MpegTsWriter, doOutputBuffers _: [(UnsafeRawBufferPointer, Int)]) {}
}

extension RistStream: RistSenderContextDelegate {
    func ristSenderContextStats(_: RistSenderContext, stats: RistStats) {
        ristQueue.async {
            self.handleStatsInner(stats: stats)
        }
    }

    func ristSenderContextPeerConnected(_: RistSenderContext, peerId: UInt32) {
        ristQueue.async {
            self.handlePeerConnectedInner(peerId: peerId)
        }
    }

    func ristSenderContextPeerDisconnected(_: RistSenderContext, peerId: UInt32) {
        ristQueue.async {
            self.handlePeerDisconnectedInner(peerId: peerId)
        }
    }

    private func handlePeerConnectedInner(peerId: UInt32) {
        logger.info("rist: Peer \(peerId) connected")
        getPeerById(peerId: peerId)?.setConnected()
        checkConnected()
    }

    private func handlePeerDisconnectedInner(peerId: UInt32) {
        logger.info("rist: Peer \(peerId) disconnected")
        getPeerById(peerId: peerId)?.setDisconnected()
        checkDisconnected()
    }
}
