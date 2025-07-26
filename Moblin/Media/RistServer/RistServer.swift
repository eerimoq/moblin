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
    private var clients: [RistServerClient] = []
    weak var delegate: (any RistServerDelegate)?
    private let ports: [UInt16]
    private let timecodesEnabled: Bool
    var totalBytesReceived: UInt64 = 0
    private var prevTotalBytesReceived: UInt64 = 0
    var numberOfConnectedClients = 0

    init(ports: [UInt16], timecodesEnabled: Bool) {
        self.ports = ports
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
            numberOfConnectedClients
        }
    }

    private func startInner() {
        logger.info("rist-server: Starting")
        numberOfConnectedClients = 0
        for port in ports {
            if let client = RistServerClient(port: port, timecodesEnabled: timecodesEnabled) {
                client.server = self
                client.start()
                clients.append(client)
            } else {
                logger.info("rist-server: Failed to create client for port: \(port)")
            }
        }
    }

    private func stopInner() {
        logger.info("rist-server: Stopping")
        numberOfConnectedClients = 0
        for client in clients {
            client.stop()
        }
        clients.removeAll()
    }
}
