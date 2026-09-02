import AVFoundation
import libsrt

class SrtServerClient {
    private weak var server: SrtServer?
    private let cameraId: UUID
    private let reader: MpegTsReader

    init(server: SrtServer,
         cameraId: UUID,
         latency: Double,
         timecodesEnabled: Bool,
         softwareDecoding: Bool)
    {
        self.server = server
        self.cameraId = cameraId
        reader = MpegTsReader(name: "srt-server",
                              decoderQueue: srtlaServerQueue,
                              timecodesEnabled: timecodesEnabled,
                              softwareDecoding: softwareDecoding,
                              targetLatency: latency)
        reader.delegate = self
    }

    func run(clientSocket: Int32) {
        let packetSize = 2048
        nonisolated(unsafe)
        var packet = Data(count: packetSize)
        while server?.running == true {
            let done = autoreleasepool { () -> Bool in
                // No idea why, but OBS does not work without this.
                packet.count = packetSize
                let count = packet.withUnsafeMutableBytes { pointer in
                    srt_recvmsg(clientSocket, pointer.baseAddress, Int32(packetSize))
                }
                guard count != SRT_ERROR else {
                    return true
                }
                packet.count = Int(count)
                server?.srtlaServer?.bitrateStats.mutate {
                    $0.add(bytesTransferred: packet.count)
                }
                do {
                    try reader.handlePacketFromClient(packet: packet)
                } catch {
                    logger.info("srt-server-client: Got corrupt packet \(error).")
                }
                return false
            }
            if done {
                break
            }
        }
        srt_close(clientSocket)
    }
}

extension SrtServerClient: MpegTsReaderDelegate {
    func mpegTsReaderAudioBuffer(_ sampleBuffer: CMSampleBuffer) {
        server?.srtlaServer?.delegate.srtlaServerOnAudioBuffer(
            cameraId: cameraId,
            sampleBuffer: sampleBuffer
        )
    }

    func mpegTsReaderVideoBuffer(_ sampleBuffer: CMSampleBuffer) {
        server?.srtlaServer?.delegate.srtlaServerOnVideoBuffer(
            cameraId: cameraId,
            sampleBuffer: sampleBuffer
        )
    }

    func mpegTsReaderSetTargetLatencies(_ videoTargetLatency: Double, _ audioTargetLatency: Double) {
        server?.srtlaServer?.delegate.srtlaServerSetTargetLatencies(
            cameraId: cameraId,
            videoTargetLatency,
            audioTargetLatency
        )
    }
}
