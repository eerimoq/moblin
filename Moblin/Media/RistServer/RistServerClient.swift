import AVFoundation
import Rist

let ristServerClientLatency = 2.0

class RistServerClient {
    weak var server: RistServer?
    private var reader = MpegTsReader(decoderQueue: ristServerQueue,
                                      timecodesEnabled: false,
                                      targetLatency: ristServerClientLatency)
    private let timecodesEnabled: Bool
    private var receivedPackets: [Data] = []
    private var latestReceivedPacketsTime = ContinuousClock.now
    private var connected = false
    private let virtualDestinationPort: UInt16

    init?(virtualDestinationPort: UInt16, timecodesEnabled: Bool) {
        self.virtualDestinationPort = virtualDestinationPort
        self.timecodesEnabled = timecodesEnabled
        reader.delegate = self
    }

    func handlePacketFromClient(packet: Data) {
        do {
            try reader.handlePacketFromClient(packet: packet)
        } catch {
            logger.info("rist-server-client: Got corrupt packet \(error).")
        }
    }
}

extension RistServerClient: MpegTsReaderDelegate {
    func mpegTsReaderAudioBuffer(_ sampleBuffer: CMSampleBuffer) {
        server?.delegate?.ristServerOnAudioBuffer(virtualDestinationPort: virtualDestinationPort, sampleBuffer)
    }

    func mpegTsReaderVideoBuffer(_ sampleBuffer: CMSampleBuffer) {
        server?.delegate?.ristServerOnVideoBuffer(virtualDestinationPort: virtualDestinationPort, sampleBuffer)
    }

    func mpegTsReaderSetTargetLatencies(_ videoTargetLatency: Double, _ audioTargetLatency: Double) {
        server?.delegate?.ristServerSetTargetLatencies(virtualDestinationPort: virtualDestinationPort,
                                                       videoTargetLatency,
                                                       audioTargetLatency)
    }
}
