import AVFoundation
import libsrt

let srtServerClientLatency = 0.5

class SrtServerClient {
    private weak var server: SrtServer?
    private let streamId: String
    private let reader: MpegTsReader

    init(server: SrtServer, streamId: String, timecodesEnabled: Bool) {
        self.server = server
        self.streamId = streamId
        reader = MpegTsReader(decoderQueue: srtlaServerQueue,
                              timecodesEnabled: timecodesEnabled,
                              targetLatency: srtServerClientLatency)
        reader.delegate = self
    }

    func run(clientSocket: Int32) {
        let packetSize = 2048
        var packet = Data(count: packetSize)
        while server?.running == true {
            // No idea why, but OBS does not work without this.
            packet.count = packetSize
            let count = packet.withUnsafeMutableBytes { pointer in
                srt_recvmsg(clientSocket, pointer.baseAddress, Int32(packetSize))
            }
            guard count != SRT_ERROR else {
                break
            }
            packet.count = Int(count)
            server?.srtlaServer?.totalBytesReceived.mutate { $0 += UInt64(count) }
            do {
                try reader.handlePacketFromClient(packet: packet)
            } catch {
                logger.info("srt-server-client: Got corrupt packet \(error).")
            }
        }
        srt_close(clientSocket)
    }
}

extension SrtServerClient: VideoDecoderDelegate {
    func videoDecoderOutputSampleBuffer(_: VideoDecoder, _ sampleBuffer: CMSampleBuffer) {
        server?.srtlaServer?.delegate?.srtlaServerOnVideoBuffer(
            streamId: streamId,
            sampleBuffer: sampleBuffer
        )
    }
}

extension SrtServerClient: MpegTsReaderDelegate {
    func mpegTsReaderAudioBuffer(_ sampleBuffer: CMSampleBuffer) {
        server?.srtlaServer?.delegate?.srtlaServerOnAudioBuffer(streamId: streamId, sampleBuffer: sampleBuffer)
    }

    func mpegTsReaderVideoBuffer(_ sampleBuffer: CMSampleBuffer) {
        server?.srtlaServer?.delegate?.srtlaServerOnVideoBuffer(streamId: streamId, sampleBuffer: sampleBuffer)
    }

    func mpegTsReaderSetTargetLatencies(_ videoTargetLatency: Double, _ audioTargetLatency: Double) {
        server?.srtlaServer?.delegate?.srtlaServerSetTargetLatencies(
            streamId: streamId,
            videoTargetLatency,
            audioTargetLatency
        )
    }
}
