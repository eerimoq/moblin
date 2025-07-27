import AVFoundation
import Foundation
import Rist

struct RistServerStats {
    var total: UInt64
    var speed: UInt64
}

protocol RistServerDelegate: AnyObject {
    func ristServerOnConnected(port: UInt16)
    func ristServerOnDisconnected(port: UInt16, reason: String)
    func ristServerOnVideoBuffer(virtualDestinationPort: UInt16, _ sampleBuffer: CMSampleBuffer)
    func ristServerOnAudioBuffer(virtualDestinationPort: UInt16, _ sampleBuffer: CMSampleBuffer)
    func ristServerSetTargetLatencies(
        virtualDestinationPort: UInt16,
        _ videoTargetLatency: Double,
        _ audioTargetLatency: Double
    )
}

let ristServerQueue = DispatchQueue(label: "com.eerimoq.rist-server")

class RistServer {
    private var port: UInt16
    private var context: RistReceiverContext?
    private var clientsByVirtualDestinationPort: [UInt16: RistServerClient] = [:]
    weak var delegate: (any RistServerDelegate)?
    private let virtualDestinationPorts: [UInt16]
    private let timecodesEnabled: Bool
    var totalBytesReceived: UInt64 = 0
    private var prevTotalBytesReceived: UInt64 = 0

    init?(port: UInt16, virtualDestinationPorts: [UInt16], timecodesEnabled: Bool) {
        self.port = port
        self.virtualDestinationPorts = virtualDestinationPorts
        self.timecodesEnabled = timecodesEnabled
    }

    func start() {
        ristServerQueue.async {
            self.startInner()
        }
    }

    func stop() {
        ristServerQueue.async {
            self.stopInner()
        }
    }

    func updateStats() -> RistServerStats {
        return ristServerQueue.sync {
            let speed = totalBytesReceived - prevTotalBytesReceived
            prevTotalBytesReceived = totalBytesReceived
            return RistServerStats(total: totalBytesReceived, speed: speed)
        }
    }

    func getNumberOfClients() -> Int {
        return ristServerQueue.sync {
            clientsByVirtualDestinationPort.count
        }
    }

    private func startInner() {
        logger.info("rist-server: Starting")
        context = RistReceiverContext(inputUrl: "rist://@0.0.0.0:\(port)?rtt-min=100")
        context?.delegate = self
        _ = context?.start()
    }

    private func stopInner() {
        logger.info("rist-server: Stopping")
        context = nil
        for virtualDestinationPort in clientsByVirtualDestinationPort.keys {
            delegate?.ristServerOnDisconnected(port: virtualDestinationPort, reason: "")
        }
        clientsByVirtualDestinationPort.removeAll()
    }

    private func peerConnected(_ virtualDestinationPort: UInt16) {
        logger.info("rist-server: Connected virtual destination port \(virtualDestinationPort)")
        guard virtualDestinationPorts.contains(virtualDestinationPort) else {
            logger.info("rist-server: Ignoring unknown virtual destination port \(virtualDestinationPort)")
            return
        }
        let client = RistServerClient(virtualDestinationPort: virtualDestinationPort,
                                      timecodesEnabled: timecodesEnabled)
        client?.server = self
        clientsByVirtualDestinationPort[virtualDestinationPort] = client
        delegate?.ristServerOnConnected(port: virtualDestinationPort)
    }

    private func peerDisconnected(_ virtualDestinationPort: UInt16) {
        logger.info("rist-server: Disconnected virtual destination port \(virtualDestinationPort)")
        if clientsByVirtualDestinationPort.removeValue(forKey: virtualDestinationPort) != nil {
            delegate?.ristServerOnDisconnected(port: virtualDestinationPort, reason: "")
        }
    }

    private func peerReceivedData(_ virtualDestinationPort: UInt16, packets: [Data]) {
        guard let client = clientsByVirtualDestinationPort[virtualDestinationPort] else {
            return
        }
        for packet in packets {
            totalBytesReceived += UInt64(packet.count)
            client.handlePacketFromClient(packet: packet)
        }
    }
}

extension RistServer: RistReceiverContextDelegate {
    func ristReceiverContextConnected(_ virtualDestinationPort: UInt16) {
        ristServerQueue.async {
            self.peerConnected(virtualDestinationPort)
        }
    }

    func ristReceiverContextDisconnected(_ virtualDestinationPort: UInt16) {
        ristServerQueue.async {
            self.peerDisconnected(virtualDestinationPort)
        }
    }

    func ristReceiverContextReceivedData(_ virtualDestinationPort: UInt16, packets: [Data]) {
        ristServerQueue.async {
            self.peerReceivedData(virtualDestinationPort, packets: packets)
        }
    }
}
