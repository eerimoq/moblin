import AVFoundation
import Foundation

protocol SrtStreamMoblinDelegate: AnyObject {
    func srtStreamMoblinConnected()
    func srtStreamMoblinDisconnected()
    func srtStreamMoblinOutput(packet: Data)
}

class SrtStreamMoblin {
    private let writer: MpegTsWriter
    weak var srtStreamDelegate: SrtStreamMoblinDelegate?
    private let processor: Processor
    private var srtSender: SrtSender?

    init(processor: Processor, timecodesEnabled: Bool, delegate: SrtStreamMoblinDelegate) {
        self.processor = processor
        writer = MpegTsWriter(timecodesEnabled: timecodesEnabled, newSrt: true)
        srtStreamDelegate = delegate
        writer.delegate = self
    }

    func open(streamId: String?, latency: UInt16) {
        srtSender = SrtSender(streamId: streamId, latency: latency)
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
        return srtSender?.getPerformanceData()
    }

    private func write(data: Data) {
        data.withUnsafeBytes { buffer in
            write(buffer: buffer)
        }
    }

    private func write(buffer: UnsafeRawBufferPointer) {
        guard let srtSender else {
            return
        }
        let now = ContinuousClock.now
        for offset in stride(from: 0, to: buffer.count, by: payloadSize) {
            let length = min(payloadSize, buffer.count - offset)
            let payload = UnsafeRawBufferPointer(rebasing: buffer[offset ..< offset + length])
            let packet = srtSender.newDataPacket(payload: payload)
            srtSender.enqueue(packet: packet, now: now)
        }
        srtSender.send(now: now)
    }
}

extension SrtStreamMoblin: MpegTsWriterDelegate {
    func writer(_: MpegTsWriter, doOutput data: Data) {
        srtlaClientQueue.async {
            self.write(data: data)
        }
    }

    func writer(_: MpegTsWriter, doOutputPointer _: UnsafeRawBufferPointer, count _: Int) {}
}

extension SrtStreamMoblin: SrtSenderDelegate {
    func srtSenderConnected() {
        processorControlQueue.async {
            self.processor.startEncoding(self.writer)
            self.writer.startRunning()
            self.srtStreamDelegate?.srtStreamMoblinConnected()
        }
    }

    func srtSenderDisconnected() {
        processorControlQueue.async {
            self.writer.stopRunning()
            self.processor.stopEncoding(self.writer)
            self.srtStreamDelegate?.srtStreamMoblinDisconnected()
        }
    }

    func srtSenderOutput(packet: Data) {
        srtStreamDelegate?.srtStreamMoblinOutput(packet: packet)
    }
}
