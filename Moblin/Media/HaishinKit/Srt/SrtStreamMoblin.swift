import AVFoundation
import Foundation

protocol SrtStreamMoblinDelegate: AnyObject {
    func srtStreamMoblinConnected()
    func srtStreamMoblinDisconnected()
    func srtStreamMoblinOutput(packet: Data)
}

class SrtStreamMoblin {
    private let writer: MpegTsWriter
    private let delegate: any SrtStreamMoblinDelegate
    private let processor: Processor
    private var srtSender: SrtSender?

    init(processor: Processor, timecodesEnabled: Bool, delegate: any SrtStreamMoblinDelegate) {
        self.processor = processor
        writer = MpegTsWriter(timecodesEnabled: timecodesEnabled, newSrt: true)
        self.delegate = delegate
        writer.delegate = self
    }

    func open(streamId: String?, latency: UInt16, experimental: Bool) {
        srtSender = SrtSender(streamId: streamId, latency: latency, experimental: experimental)
        srtSender?.delegate = self
        srtSender?.start()
    }

    func close() {
        srtSender?.stop()
        srtSender = nil
    }

    func inputPacket(packet: Data) {
        srtSender?.input(packet: packet)
    }

    func getPerformanceData() -> SrtPerformanceData? {
        srtSender?.getPerformanceData()
    }

    private func write(data: Data, containsAudio: Bool) {
        data.withUnsafeBytes { buffer in
            write(buffer: buffer, containsAudio: containsAudio)
        }
    }

    private func write(buffer: UnsafeRawBufferPointer, containsAudio: Bool) {
        guard let srtSender else {
            return
        }
        let now = ContinuousClock.now
        for offset in stride(from: 0, to: buffer.count, by: payloadSize) {
            let length = min(payloadSize, buffer.count - offset)
            let payload = UnsafeRawBufferPointer(rebasing: buffer[offset ..< offset + length])
            let packet = srtSender.newDataPacket(payload: payload)
            packet.containsAudio = containsAudio
            srtSender.enqueue(packet: packet, now: now)
        }
        srtSender.send(now: now)
    }
}

extension SrtStreamMoblin: MpegTsWriterDelegate {
    func writer(_: MpegTsWriter, doOutput data: Data, containsAudio: Bool) {
        srtlaClientQueue.async {
            self.write(data: data, containsAudio: containsAudio)
        }
    }

    func writer(_: MpegTsWriter, doOutputPointer _: UnsafeRawBufferPointer, count _: Int) {}
}

extension SrtStreamMoblin: SrtSenderDelegate {
    func srtSenderConnected() {
        processorControlQueue.async {
            self.processor.startEncoding(self.writer)
            self.writer.startRunning()
            self.delegate.srtStreamMoblinConnected()
        }
    }

    func srtSenderDisconnected() {
        processorControlQueue.async {
            self.writer.stopRunning()
            self.processor.stopEncoding(self.writer)
            self.delegate.srtStreamMoblinDisconnected()
        }
    }

    func srtSenderOutput(packet: Data) {
        delegate.srtStreamMoblinOutput(packet: packet)
    }
}
