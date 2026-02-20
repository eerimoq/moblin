import AVFoundation
import Rist

class RistServerClient {
    weak var server: RistServer?
    private let reader: MpegTsReader
    private let virtualDestinationPort: UInt16

    init?(virtualDestinationPort: UInt16, latency: Double) {
        self.virtualDestinationPort = virtualDestinationPort
        reader = MpegTsReader(decoderQueue: ristServerQueue,
                              timecodesEnabled: false,
                              targetLatency: latency)
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
        server?.delegate?.ristServerOnAudioBuffer(
            virtualDestinationPort: virtualDestinationPort,
            sampleBuffer
        )
    }

    func mpegTsReaderVideoBuffer(_ sampleBuffer: CMSampleBuffer) {
        server?.delegate?.ristServerOnVideoBuffer(
            virtualDestinationPort: virtualDestinationPort,
            sampleBuffer
        )
    }

    func mpegTsReaderSetTargetLatencies(_ videoTargetLatency: Double, _ audioTargetLatency: Double) {
        server?.delegate?.ristServerSetTargetLatencies(virtualDestinationPort: virtualDestinationPort,
                                                       videoTargetLatency,
                                                       audioTargetLatency)
    }
}
