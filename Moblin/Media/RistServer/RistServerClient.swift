import AVFoundation
import Rist

let ristServerClientLatency = 2.0

class RistServerClient {
    private let context: RistReceiverContext
    weak var server: RistServer?
    private var reader = MpegTsReader(decoderQueue: ristServerQueue,
                                      timecodesEnabled: false,
                                      targetLatency: ristServerClientLatency)
    private let port: UInt16
    private let timecodesEnabled: Bool
    private var receivedPackets: [Data] = []
    private var latestReceivedPacketsTime = ContinuousClock.now

    init?(port: UInt16, timecodesEnabled: Bool) {
        self.port = port
        self.timecodesEnabled = timecodesEnabled
        guard let context = RistReceiverContext(inputUrl: "rist://@0.0.0.0:\(port)?rtt-min=100") else {
            logger.info("rist-server-client: Failed to create context")
            return nil
        }
        self.context = context
        context.delegate = self
        reader.delegate = self
    }

    func start() {
        _ = context.start()
    }

    private func handlePacketFromClient(packet: Data) {
        do {
            try reader.handlePacketFromClient(packet: packet)
        } catch {
            logger.info("rist-server-client: Got corrupt packet \(error).")
        }
    }
}

extension RistServerClient: RistReceiverContextDelegate {
    func ristReceiverContextConnected(_: Rist.RistReceiverContext) {
        receivedPackets = []
        ristServerQueue.async {
            self.reader = MpegTsReader(decoderQueue: ristServerQueue,
                                       timecodesEnabled: self.timecodesEnabled,
                                       targetLatency: ristServerClientLatency)
            self.reader.delegate = self
            self.server?.numberOfConnectedClients += 1
            self.server?.delegate?.ristServerOnConnected(port: self.port)
        }
    }

    func ristReceiverContextDisconnected(_: Rist.RistReceiverContext) {
        ristServerQueue.async {
            self.server?.numberOfConnectedClients -= 1
            self.server?.delegate?.ristServerOnDisconnected(port: self.port, reason: "")
        }
    }

    func ristReceiverContextReceivedData(_: Rist.RistReceiverContext, data: Data) {
        receivedPackets.append(data)
        let now = ContinuousClock.now
        guard latestReceivedPacketsTime.duration(to: now) > .milliseconds(50) else {
            return
        }
        latestReceivedPacketsTime = now
        let packets = receivedPackets
        receivedPackets = []
        ristServerQueue.async {
            for packet in packets {
                self.server?.totalBytesReceived += UInt64(packet.count)
                self.handlePacketFromClient(packet: packet)
            }
        }
    }
}

extension RistServerClient: MpegTsReaderDelegate {
    func mpegTsReaderAudioBuffer(_ sampleBuffer: CMSampleBuffer) {
        server?.delegate?.ristServerOnAudioBuffer(port: port, sampleBuffer)
    }

    func mpegTsReaderVideoBuffer(_ sampleBuffer: CMSampleBuffer) {
        server?.delegate?.ristServerOnVideoBuffer(port: port, sampleBuffer)
    }

    func mpegTsReaderSetTargetLatencies(_ videoTargetLatency: Double, _ audioTargetLatency: Double) {
        server?.delegate?.ristServerSetTargetLatencies(port: port, videoTargetLatency, audioTargetLatency)
    }
}
