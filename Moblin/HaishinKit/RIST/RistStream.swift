import Foundation
import Network
import Rist

class RistRemotePeer {
    let interfaceName: String
    let peer: RistPeer
    var stats: RistSenderStats?

    init(interfaceName: String, peer: RistPeer) {
        self.interfaceName = interfaceName
        self.peer = peer
    }
}

class RistStream: NetStream {
    weak var connection: RistConnection?
    private var context: RistContext?
    private var peers: [RistRemotePeer] = []
    private let writer = MpegTsWriter()
    private var networkPathMonitor: NWPathMonitor?
    private var bonding: Bool = false
    private var url: String = ""

    init(_ connection: RistConnection) {
        super.init()
        self.connection = connection
        self.connection?.stream = self
        writer.delegate = self
    }

    deinit {
        self.connection?.stream = nil
        self.connection = nil
    }

    func start(url: String, bonding: Bool) {
        lockQueue.async {
            self.startInner(url: url, bonding: bonding)
        }
    }

    private func startInner(url: String, bonding: Bool) {
        self.url = url
        self.bonding = bonding
        guard let context = RistContext() else {
            logger.info("rist: Failed to create context")
            return
        }
        context.onStats = handleStats
        self.context = context
        if bonding {
            networkPathMonitor = .init()
            networkPathMonitor?.pathUpdateHandler = handleNetworkPathUpdate(path:)
            networkPathMonitor?.start(queue: lockQueue)
        } else {
            addPeer(url, "")
        }
        if !context.start() {
            logger.info("rist: Failed to start")
            return
        }
        writer.expectedMedias.insert(.video)
        writer.expectedMedias.insert(.audio)
        mixer.startEncoding(writer)
        mixer.startRunning()
        writer.startRunning()
    }

    func stop() {
        lockQueue.async {
            self.stopInner()
        }
    }

    private func stopInner() {
        networkPathMonitor?.cancel()
        networkPathMonitor = nil
        writer.stopRunning()
        mixer.stopEncoding()
        peers.removeAll()
        context = nil
    }

    func getSpeed() -> UInt64 {
        var totalBandwidth: UInt64 = 0
        lockQueue.sync {
            for peer in peers {
                if let stats = peer.stats {
                    totalBandwidth += stats.bandwidth + stats.retryBandwidth
                }
            }
        }
        return totalBandwidth
    }

    func connectionStatistics() -> String? {
        var connections: [BondingConnection] = []
        lockQueue.sync {
            for peer in peers {
                var connection = BondingConnection(name: peer.interfaceName, usage: 0)
                if let stats = peer.stats {
                    connection.usage = stats.bandwidth + stats.retryBandwidth
                }
                connections.append(connection)
            }
        }
        return bondingStatistics(connections: connections)
    }

    private func handleNetworkPathUpdate(path: NWPath) {
        guard bonding else {
            return
        }
        let interfaceNames = path.availableInterfaces.map { $0.name }
        var removedInterfaceNames: [String] = []
        for peer in peers {
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
            addPeer(makeBondingUrl(url, interfaceName), interfaceName)
        }
    }

    private func makeBondingUrl(_ url: String, _ interfaceName: String) -> String? {
        guard let url = URL(string: url) else {
            return nil
        }
        guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        urlComponents.query = url.query
        var queryItems: [URLQueryItem] = urlComponents.queryItems ?? []
        queryItems.append(URLQueryItem(name: "miface", value: interfaceName))
        queryItems.append(URLQueryItem(name: "weight", value: "1"))
        urlComponents.queryItems = queryItems
        return urlComponents.url?.absoluteString
    }

    private func handleStats(stats: RistStats) {
        lockQueue.async {
            self.handleStatsInner(stats: stats)
        }
    }

    private func handleStatsInner(stats: RistStats) {
        logger.info("""
        rist: peer \(stats.sender.peerId), rtt \(stats.sender.rtt), \
        sent \(stats.sender.sentPackets), received \(stats.sender.receivedPackets), \
        retransmitted \(stats.sender.retransmittedPackets), quality \(stats.sender.quality), \
        bandwidth \(formatBytesPerSecond(speed: Int64(stats.sender.bandwidth))), \
        retry bandwidth \(formatBytesPerSecond(speed: Int64(stats.sender.retryBandwidth)))
        """)
        peers.first(where: { $0.peer.getId() == stats.sender.peerId })?.stats = stats.sender
        var totalBandwidth: UInt64 = 0
        for peer in peers {
            guard let stats = peer.stats else {
                continue
            }
            totalBandwidth += stats.bandwidth
            totalBandwidth += stats.retryBandwidth
        }
        // logger.info("rist: Total bandwidth \(formatBytesPerSecond(speed: Int64(totalBandwidth)))")
    }

    private func addPeer(_ url: String?, _ interfaceName: String) {
        logger.info("rist: Adding peer for interface \(interfaceName)")
        guard let url, let peer = context?.addPeer(url: url) else {
            logger.info("rist: Failed to add peer")
            return
        }
        peers.append(RistRemotePeer(interfaceName: interfaceName, peer: peer))
    }

    private func send(data: Data) {
        if context?.send(data: data) != true {
            logger.info("rist: Failed to send")
        }
    }

    private func send(dataPointer: UnsafeRawBufferPointer, count: Int) {
        if context?.send(dataPointer: dataPointer, count: count) != true {
            logger.info("rist: Failed to send")
        }
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
