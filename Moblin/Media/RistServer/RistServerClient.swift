import AVFoundation
import Rist

class RistServerClient {
    weak var server: RistServer?
    private let reader: MpegTsReader
    private let cameraId: UUID

    init(cameraId: UUID, latency: Double, softwareDecoding: Bool) {
        self.cameraId = cameraId
        reader = MpegTsReader(name: "rist-server",
                              decoderQueue: ristServerQueue,
                              timecodesEnabled: false,
                              softwareDecoding: softwareDecoding,
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
        server?.delegate.ristServerOnAudioBuffer(cameraId: cameraId, sampleBuffer)
    }

    func mpegTsReaderVideoBuffer(_ sampleBuffer: CMSampleBuffer) {
        server?.delegate.ristServerOnVideoBuffer(cameraId: cameraId, sampleBuffer)
    }
}
