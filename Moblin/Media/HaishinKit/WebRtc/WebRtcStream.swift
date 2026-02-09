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
    private let dtlsSession: DtlsSession?
    private let srtpSession: SrtpSession
    weak var delegate: WebRtcStreamDelegate?
    private var url: String = ""
    private var totalByteCount: Int64 = 0
    private let fingerprint: String

    private let videoPayloadType: UInt8 = 96
    private let audioPayloadType: UInt8 = 111
    private let videoClockRate: UInt32 = 90000
    private let audioClockRate: UInt32 = 48000

    init(processor: Processor, timecodesEnabled: Bool, delegate: WebRtcStreamDelegate) {
        self.processor = processor
        self.delegate = delegate
        dtlsSession = DtlsSession()
        srtpSession = SrtpSession()
        fingerprint = dtlsSession?.fingerprint ?? WebRtcStream.generateFallbackFingerprint()
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

    // Fallback fingerprint when DTLS certificate generation fails.
    private static func generateFallbackFingerprint() -> String {
        let bytes = (0 ..< 32).map { _ in UInt8.random(in: 0 ... 255) }
        let hex = bytes.map { String(format: "%02X", $0) }.joined(separator: ":")
        return "sha-256 \(hex)"
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
            icePwd: whipSession.localIcePwd,
            fingerprint: fingerprint
        )
        whipSession.start(url: url, offer: offer)
    }

    private func stopInternal() {
        state = .disconnected
        dtlsSession?.stop()
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
        dtlsSession?.delegate = self
        if let candidate = whipSession.remoteCandidates.first {
            dtlsSession?.start(host: candidate.address, port: UInt16(candidate.port))
        }
        processorControlQueue.async {
            self.processor.startEncoding(self.writer)
            self.writer.startRunning()
        }
        delegate?.webRtcStreamOnConnected()
    }

    private func handleDisconnected() {
        state = .disconnected
        dtlsSession?.stop()
        processorControlQueue.async {
            self.writer.stopRunning()
            self.processor.stopEncoding(self.writer)
        }
        delegate?.webRtcStreamOnDisconnected()
    }
}

extension WebRtcStream: DtlsSessionDelegate {
    func dtlsSessionOnState(_: DtlsSession, state: DtlsState) {
        webRtcQueue.async {
            switch state {
            case .connected:
                logger.info("webrtc: DTLS connected")
                if let keyingMaterial = self.dtlsSession?.getSrtpKeyingMaterial() {
                    self.srtpSession.deriveKeys(keyingMaterial: keyingMaterial, isClient: true)
                }
            case .failed:
                logger.info("webrtc: DTLS failed")
                self.delegate?.webRtcStreamOnDisconnected()
            case .closed:
                logger.info("webrtc: DTLS closed")
            default:
                break
            }
        }
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
