import AVFoundation
import Foundation

import HaishinKit
import RTCHaishinKit

protocol WhipStreamDelegate: AnyObject {
    func whipStreamOnConnected()
    func whipStreamOnDisconnected(reason: String)
}

final class WhipStream: NSObject {
    private let processor: Processor
    private weak var delegate: (any WhipStreamDelegate)?

    private var session: (any Session)?
    private var rtcStream: RTCStream?
    private var readyStateTask: Task<Void, Never>?
    private var didReportConnected = false

    init(processor: Processor, delegate: WhipStreamDelegate) {
        self.processor = processor
        self.delegate = delegate
    }

    func start(
        endpointUrl: URL,
        settings: SettingsStreamWhip,
        videoDimensions: CMVideoDimensions
    ) {
        Task { [weak self] in
            guard let self else { return }
            await self.startInternal(
                endpointUrl: endpointUrl,
                settings: settings,
                videoDimensions: videoDimensions
            )
        }
    }

    func stop() {
        Task { [weak self] in
            guard let self else { return }
            await self.stopInternal()
        }
    }

    private func startInternal(
        endpointUrl: URL,
        settings: SettingsStreamWhip,
        videoDimensions: CMVideoDimensions
    ) async {
        await stopInternal()
        didReportConnected = false
        do {
            guard let session = try await SessionBuilderFactory.shared
                .make(endpointUrl)
                .setMode(.publish)
                .setConfiguration(nil)
                .build()
            else {
                throw NSError(domain: "Moblin", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "WHIP session could not be created",
                ])
            }
            self.session = session
            await session.setMaxRetryCount(settings.maxRetryCount)

            let rtcStream = (await session.stream) as? RTCStream
            guard let rtcStream else {
                throw NSError(domain: "Moblin", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "WHIP session stream is not RTCStream",
                ])
            }
            self.rtcStream = rtcStream

            await rtcStream.setDirection(.sendonly)
            try await rtcStream.setAudioSettings(.init(channelMap: [0, 0], format: .opus))
            try await rtcStream.setVideoSettings(.init(videoSize: .init(
                width: Double(videoDimensions.width),
                height: Double(videoDimensions.height)
            )))

            readyStateTask = Task { [weak self] in
                guard let self else { return }
                for await state in await session.readyState {
                    switch state {
                    case .open:
                        processorControlQueue.async {
                            self.processor.startEncoding(self)
                            guard !self.didReportConnected else { return }
                            self.didReportConnected = true
                            DispatchQueue.main.async {
                                self.delegate?.whipStreamOnConnected()
                            }
                        }
                    case .closing, .closed:
                        processorControlQueue.async {
                            self.processor.stopEncoding(self)
                        }
                    default:
                        break
                    }
                }
            }

            try await session.connect { [weak self] in
                guard let self else { return }
                processorControlQueue.async {
                    self.processor.stopEncoding(self)
                }
                DispatchQueue.main.async {
                    self.delegate?.whipStreamOnDisconnected(reason: String(localized: "WHIP disconnected"))
                }
            }
        } catch {
            processorControlQueue.async { [weak self] in
                guard let self else { return }
                self.processor.stopEncoding(self)
            }
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.whipStreamOnDisconnected(reason: "WHIP connect failed: \(error)")
            }
            await stopInternal()
        }
    }

    private func stopInternal() async {
        readyStateTask?.cancel()
        readyStateTask = nil
        didReportConnected = false

        processorControlQueue.async { [weak self] in
            guard let self else { return }
            self.processor.stopEncoding(self)
        }

        do {
            try await session?.close()
        } catch {
            // Best effort close.
        }
        self.session = nil
        self.rtcStream = nil
    }
}

extension WhipStream: AudioEncoderDelegate {
    func audioEncoderOutputFormat(_: AVAudioFormat) {}

    func audioEncoderOutputBuffer(_ buffer: AVAudioCompressedBuffer, _ presentationTimeStamp: CMTime) {
        guard let rtcStream else { return }
        let sampleRate = processor.getAudioEncoder().getSampleRate() ?? 48_000
        let sampleTime = AVAudioFramePosition(presentationTimeStamp.seconds * sampleRate)
        let when = AVAudioTime(sampleTime: sampleTime, atRate: sampleRate)
        Task { await rtcStream.append(buffer, when: when) }
    }
}

extension WhipStream: VideoEncoderDelegate {
    func videoEncoderOutputFormat(_: VideoEncoder, _: CMFormatDescription) {}

    func videoEncoderOutputSampleBuffer(
        _: VideoEncoder,
        _ sampleBuffer: CMSampleBuffer,
        _: CMTime
    ) {
        guard let rtcStream else { return }
        Task { await rtcStream.append(sampleBuffer) }
    }
}

