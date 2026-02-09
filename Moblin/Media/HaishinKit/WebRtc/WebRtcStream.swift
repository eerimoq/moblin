import AVFoundation
import Foundation

private let webRtcQueue = DispatchQueue(label: "com.eerimoq.Moblin.webrtc")

protocol WebRtcStreamDelegate: AnyObject {
    func webRtcStreamOnConnected()
    func webRtcStreamOnDisconnected()
}

private enum WebRtcStreamState {
    case idle
    case connecting
    case connected
    case disconnected
}

class WebRtcStream {
    private var state: WebRtcStreamState = .idle
    private let whipSession: WhipSession
    private let iceAgent: IceAgent
    private let videoSequencer: RtpSequencer
    private let audioSequencer: RtpSequencer
    private let writer: MpegTsWriter
    private let processor: Processor
    weak var delegate: WebRtcStreamDelegate?
    private var url: String = ""
    private var totalByteCount: Int64 = 0

    private let videoPayloadType: UInt8 = 96
    private let audioPayloadType: UInt8 = 111
    private let videoClockRate: UInt32 = 90000
    private let audioClockRate: UInt32 = 48000

    init(processor: Processor, timecodesEnabled: Bool, delegate: WebRtcStreamDelegate) {
        self.processor = processor
        self.delegate = delegate
        whipSession = WhipSession()
        iceAgent = IceAgent()
        videoSequencer = RtpSequencer(
            payloadType: videoPayloadType,
            clockRate: videoClockRate
        )
        audioSequencer = RtpSequencer(
            payloadType: audioPayloadType,
            clockRate: audioClockRate
        )
        writer = MpegTsWriter(timecodesEnabled: timecodesEnabled, newSrt: false)
        writer.delegate = self
        whipSession.delegate = self
    }

    func start(url: String) {
        webRtcQueue.async {
            self.startInternal(url: url)
        }
    }

    func stop() {
        webRtcQueue.async {
            self.stopInternal()
        }
    }

    func getSpeed() -> UInt64 {
        return webRtcQueue.sync {
            UInt64(max(totalByteCount, 0))
        }
    }

    func getTotalByteCount() -> Int64 {
        return webRtcQueue.sync {
            totalByteCount
        }
    }

    private func startInternal(url: String) {
        self.url = url
        state = .connecting
        totalByteCount = 0
        let offer = sdpCreateOffer(
            videoSsrc: videoSequencer.ssrc,
            audioSsrc: audioSequencer.ssrc,
            videoPayloadType: videoPayloadType,
            audioPayloadType: audioPayloadType,
            iceUfrag: whipSession.localIceUfrag,
            icePwd: whipSession.localIcePwd
        )
        whipSession.start(url: url, offer: offer)
    }

    private func stopInternal() {
        state = .disconnected
        whipSession.stop()
        processorControlQueue.async {
            self.writer.stopRunning()
            self.processor.stopEncoding(self.writer)
        }
    }
}

extension WebRtcStream: WhipSessionDelegate {
    func whipSessionOnConnected(_: WhipSession) {
        webRtcQueue.async {
            self.handleConnected()
        }
    }

    func whipSessionOnDisconnected(_: WhipSession) {
        webRtcQueue.async {
            self.handleDisconnected()
        }
    }

    func whipSessionOnError(_: WhipSession, message: String) {
        webRtcQueue.async {
            logger.info("webrtc: WHIP error: \(message)")
            self.state = .disconnected
            self.delegate?.webRtcStreamOnDisconnected()
        }
    }

    private func handleConnected() {
        guard state == .connecting else {
            return
        }
        state = .connected
        processorControlQueue.async {
            self.processor.startEncoding(self.writer)
            self.writer.startRunning()
        }
        delegate?.webRtcStreamOnConnected()
    }

    private func handleDisconnected() {
        state = .disconnected
        processorControlQueue.async {
            self.writer.stopRunning()
            self.processor.stopEncoding(self.writer)
        }
        delegate?.webRtcStreamOnDisconnected()
    }
}

extension WebRtcStream: MpegTsWriterDelegate {
    func writer(_: MpegTsWriter, doOutput data: Data) {
        totalByteCount += Int64(data.count)
    }

    func writer(_: MpegTsWriter, doOutputPointer _: UnsafeRawBufferPointer, count: Int) {
        totalByteCount += Int64(count)
    }
}
