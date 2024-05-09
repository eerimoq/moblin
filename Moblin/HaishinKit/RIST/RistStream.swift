import Foundation
import Network
import Rist

class RistStream: NetStream {
    weak var connection: RistConnection?
    private var context: RistContext?
    private var peers: [String: RistPeer] = [:]
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

    func stop() {
        lockQueue.async {
            self.stopInner()
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

    private func stopInner() {
        networkPathMonitor?.cancel()
        networkPathMonitor = nil
        writer.stopRunning()
        mixer.stopEncoding()
        peers.removeAll()
        context = nil
    }

    private func handleNetworkPathUpdate(path: NWPath) {
        guard bonding else {
            return
        }
        let interfaceNames = path.availableInterfaces.map { $0.name }
        var removedInterfaceNames: [String] = []
        for interfaceName in peers.keys {
            if interfaceNames.contains(interfaceName) {
                continue
            }
            removedInterfaceNames.append(interfaceName)
        }
        for interfaceName in removedInterfaceNames {
            logger.info("rist: Removing peer for interface \(interfaceName)")
            peers.removeValue(forKey: interfaceName)
        }
        for interfaceName in interfaceNames {
            if peers.keys.contains(interfaceName) {
                continue
            }
            addPeer(makeBondingUrl(url, interfaceName, "1"), interfaceName)
        }
    }

    private func makeBondingUrl(_ url: String, _ interfaceName: String, _ weight: String) -> String? {
        guard let url = URL(string: url) else {
            return nil
        }
        guard var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        urlComponents.query = url.query
        var queryItems: [URLQueryItem] = urlComponents.queryItems ?? []
        queryItems.append(URLQueryItem(name: "miface", value: interfaceName))
        queryItems.append(URLQueryItem(name: "weight", value: weight))
        urlComponents.queryItems = queryItems
        return urlComponents.url?.absoluteString
    }

    private func handleStats(stats: RistStats) {
        logger.info("""
        rist: stats: peer \(stats.sender.peerId), rtt \(stats.sender.rtt), quality \(stats.sender.quality), \
        sent \(stats.sender.sentPackets), received \(stats.sender.receivedPackets), \
        bandwidth \(formatBytesPerSecond(speed: Int64(stats.sender.bandwidth))), \
        retry bandwidth \(formatBytesPerSecond(speed: Int64(stats.sender.retryBandwidth)))
        """)
    }

    private func addPeer(_ url: String?, _ interfaceName: String) {
        logger.info("rist: Adding peer for interface \(interfaceName)")
        guard let url, let peer = context?.addPeer(url: url) else {
            logger.info("rist: Failed to add peer")
            return
        }
        peers[interfaceName] = peer
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
