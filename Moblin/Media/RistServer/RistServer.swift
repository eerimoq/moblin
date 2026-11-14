import AVFoundation
import Foundation
import Rist

protocol RistServerDelegate: AnyObject {
    func ristServerOnConnected(cameraId: UUID, name: String, latency: Double)
    func ristServerOnDisconnected(cameraId: UUID, name: String)
    func ristServerOnVideoBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer)
    func ristServerOnAudioBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer)
}

let ristServerQueue = DispatchQueue(label: "com.eerimoq.rist-server")

class RistServer: @unchecked Sendable {
    private var port: UInt16
    private var context: RistReceiverContext?
    private var clientsByVirtualDestinationPort: [UInt16: RistServerClient] = [:]
    let delegate: any RistServerDelegate
    private let streams: [SettingsRistServerStream]
    private let softwareDecoding: Bool
    private let colorRange: SettingsStreamColorRange
    private let bitrateStats: Atomic<BitrateStats> = .init(BitrateStats())
    private var numberOfClients: Atomic<Int> = .init(0)

    init?(port: UInt16,
          streams: [SettingsRistServerStream],
          softwareDecoding: Bool,
          colorRange: SettingsStreamColorRange,
          delegate: any RistServerDelegate)
    {
        self.port = port
        self.streams = streams
        self.softwareDecoding = softwareDecoding
        self.colorRange = colorRange
        self.delegate = delegate
    }

    func start() {
        ristServerQueue.async {
            self.startInternal()
        }
    }

    func stop() {
        ristServerQueue.async {
            self.stopInternal()
        }
    }

    func updateStats() -> BitrateStatsInstant {
        bitrateStats.mutate { $0.update() }
    }

    func getNumberOfClients() -> Int {
        numberOfClients.value
    }

    private func startInternal() {
        logger.info("rist-server: Starting")
        context = RistReceiverContext(inputUrl: "rist://@0.0.0.0:\(port)?rtt-min=100")
        context?.delegate = self
        _ = context?.start()
    }

    private func stopInternal() {
        logger.info("rist-server: Stopping")
        context?.stop()
        context = nil
        for virtualDestinationPort in clientsByVirtualDestinationPort.keys {
            notifyDisconnected(virtualDestinationPort)
        }
        clientsByVirtualDestinationPort.removeAll()
        clientsChanged()
    }

    private func peerConnected(_ virtualDestinationPort: UInt16) {
        logger.info("rist-server: Connected virtual destination port \(virtualDestinationPort)")
        guard let stream = streams.first(where: { $0.virtualDestinationPort == virtualDestinationPort })
        else {
            logger.info("rist-server: Ignoring unknown virtual destination port \(virtualDestinationPort)")
            return
        }
        let client = RistServerClient(cameraId: stream.id,
                                      latency: stream.latencySeconds(),
                                      softwareDecoding: softwareDecoding,
                                      colorRange: colorRange)
        client.server = self
        clientsByVirtualDestinationPort[virtualDestinationPort] = client
        clientsChanged()
        delegate.ristServerOnConnected(cameraId: stream.id,
                                       name: stream.camera(),
                                       latency: stream.latencySeconds())
    }

    private func peerDisconnected(_ virtualDestinationPort: UInt16) {
        logger.info("rist-server: Disconnected virtual destination port \(virtualDestinationPort)")
        if clientsByVirtualDestinationPort.removeValue(forKey: virtualDestinationPort) != nil {
            clientsChanged()
            notifyDisconnected(virtualDestinationPort)
        }
    }

    private func notifyDisconnected(_ virtualDestinationPort: UInt16) {
        guard let stream = streams.first(where: { $0.virtualDestinationPort == virtualDestinationPort })
        else {
            return
        }
        delegate.ristServerOnDisconnected(cameraId: stream.id, name: stream.camera())
    }

    private func clientsChanged() {
        let count = clientsByVirtualDestinationPort.count
        numberOfClients.mutate { $0 = count }
    }

    private func peerReceivedData(_ virtualDestinationPort: UInt16, packets: [Data]) {
        guard let client = clientsByVirtualDestinationPort[virtualDestinationPort] else {
            return
        }
        for packet in packets {
            bitrateStats.mutate { $0.add(bytesTransferred: packet.count) }
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
