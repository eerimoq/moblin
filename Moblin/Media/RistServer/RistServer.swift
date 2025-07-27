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
    func ristServerOnVideoBuffer(port: UInt16, _ sampleBuffer: CMSampleBuffer)
    func ristServerOnAudioBuffer(port: UInt16, _ sampleBuffer: CMSampleBuffer)
    func ristServerSetTargetLatencies(
        port: UInt16,
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
}

extension RistServer: RistReceiverContextDelegate {
    func ristReceiverContextConnected(_: Rist.RistReceiverContext, _ virtualDestinationPort: UInt16) {
        ristServerQueue.async {
            guard self.virtualDestinationPorts.contains(virtualDestinationPort) else {
                logger.info("rist-server: Ignoring unknown virtual destination port \(virtualDestinationPort)")
                return
            }
            let client = RistServerClient(virtualDestinationPort: virtualDestinationPort,
                                          timecodesEnabled: self.timecodesEnabled)
            client?.server = self
            self.clientsByVirtualDestinationPort[virtualDestinationPort] = client
            self.delegate?.ristServerOnConnected(port: virtualDestinationPort)
        }
    }

    func ristReceiverContextDisconnected(_: Rist.RistReceiverContext, _ virtualDestinationPort: UInt16) {
        ristServerQueue.async {
            if self.clientsByVirtualDestinationPort.removeValue(forKey: virtualDestinationPort) != nil {
                self.delegate?.ristServerOnDisconnected(port: virtualDestinationPort, reason: "")
            }
        }
    }

    func ristReceiverContextReceivedData(_: Rist.RistReceiverContext,
                                         _ virtualDestinationPort: UInt16,
                                         packets: [Data])
    {
        ristServerQueue.async {
            guard let client = self.clientsByVirtualDestinationPort[virtualDestinationPort] else {
                return
            }
            for packet in packets {
                self.totalBytesReceived += UInt64(packet.count)
                client.handlePacketFromClient(packet: packet)
            }
        }
    }
}
