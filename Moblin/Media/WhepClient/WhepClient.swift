import AVFoundation
import CoreMedia
import Foundation

import HaishinKit
import RTCHaishinKit

protocol WhepClientDelegate: AnyObject {
    func whepClientErrorToast(title: String)
    func whepClientConnected(cameraId: UUID)
    func whepClientDisconnected(cameraId: UUID, reason: String)
    func whepClientOnVideoBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer)
    func whepClientOnAudioBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer)
}

private final class WhepClientStreamOutput: StreamOutput, @unchecked Sendable {
    private let cameraId: UUID
    private weak var delegate: (any WhepClientDelegate)?
    private let latency: Double // seconds
    private let lock = NSLock()
    // Video PTS retiming (RTSP-style): basePts + (framePts - firstFramePts) + latency
    private var basePts: Double = -1
    private var firstFramePts: Double = -1
    private var lastOutputPts: Double = -1
    // Audio PTS retiming
    private var audioBasePts: Double = -1
    private var firstAudioPts: Double = -1

    init(cameraId: UUID, delegate: (any WhepClientDelegate)?, latency: Double) {
        self.cameraId = cameraId
        self.delegate = delegate
        self.latency = latency
    }

    func stream(_ stream: some StreamConvertible, didOutput audio: AVAudioBuffer, when: AVAudioTime) {
        guard let audio = audio as? AVAudioPCMBuffer else {
            return
        }
        let audioSeconds = AVAudioTime.seconds(forHostTime: when.hostTime)
        lock.lock()
        if audioBasePts < 0 {
            audioBasePts = currentPresentationTimeStamp().seconds
            firstAudioPts = audioSeconds
        }
        let newPtsSeconds = audioBasePts + (audioSeconds - firstAudioPts) + latency
        lock.unlock()
        let pts = CMTime(seconds: newPtsSeconds, preferredTimescale: 1_000_000_000)
        guard let sampleBuffer = audio.makeSampleBuffer(pts) else {
            return
        }
        delegate?.whepClientOnAudioBuffer(cameraId: cameraId, sampleBuffer)
    }

    func stream(_ stream: some StreamConvertible, didOutput video: CMSampleBuffer) {
        let framePts = video.presentationTimeStamp.seconds
        lock.lock()
        if basePts < 0 {
            basePts = currentPresentationTimeStamp().seconds
            firstFramePts = framePts
        }
        var newPtsSeconds = basePts + (framePts - firstFramePts) + latency
        // Ensure monotonic (never go backwards).
        if newPtsSeconds <= lastOutputPts {
            newPtsSeconds = lastOutputPts + 0.001
        }
        lastOutputPts = newPtsSeconds
        lock.unlock()
        let newPts = CMTime(seconds: newPtsSeconds, preferredTimescale: 1_000_000_000)
        if let retimed = video.replacePresentationTimeStamp(newPts) {
            delegate?.whepClientOnVideoBuffer(cameraId: cameraId, retimed)
        } else {
            delegate?.whepClientOnVideoBuffer(cameraId: cameraId, video)
        }
    }
}

final class WhepClient: NSObject {
    private let cameraId: UUID
    private let url: URL
    private let latency: Double

    weak var delegate: (any WhepClientDelegate)?

    private var session: (any Session)?
    private var rtcStream: RTCStream?
    private var readyStateTask: Task<Void, Never>?
    private var didReportConnected = false

    init(cameraId: UUID, url: URL, latency: Double) {
        self.cameraId = cameraId
        self.url = url
        self.latency = latency
        super.init()
    }

    func start() {
        Task { [weak self] in
            guard let self else { return }
            await self.startInternal()
        }
    }

    func stop() {
        Task { [weak self] in
            guard let self else { return }
            await self.stopInternal()
        }
    }

    private func startInternal() async {
        await stopInternal()
        didReportConnected = false

        do {
            guard let session = try await SessionBuilderFactory.shared
                .make(url)
                .setMode(.playback)
                .setConfiguration(nil)
                .build()
            else {
                throw NSError(domain: "Moblin", code: 3, userInfo: [
                    NSLocalizedDescriptionKey: "WHEP session could not be created",
                ])
            }
            self.session = session

            let rtcStream = (await session.stream) as? RTCStream
            guard let rtcStream else {
                throw NSError(domain: "Moblin", code: 4, userInfo: [
                    NSLocalizedDescriptionKey: "WHEP session stream is not RTCStream",
                ])
            }
            self.rtcStream = rtcStream
            await rtcStream.setDirection(.recvonly)
            await rtcStream.addOutput(WhepClientStreamOutput(cameraId: cameraId, delegate: delegate, latency: latency))

            readyStateTask = Task { [weak self] in
                guard let self else { return }
                for await state in await session.readyState {
                    switch state {
                    case .open:
                        guard !self.didReportConnected else { break }
                        self.didReportConnected = true
                        DispatchQueue.main.async {
                            self.delegate?.whepClientConnected(cameraId: self.cameraId)
                        }
                    case .closing, .closed:
                        DispatchQueue.main.async {
                            self.delegate?.whepClientDisconnected(
                                cameraId: self.cameraId,
                                reason: String(localized: "WHEP disconnected")
                            )
                        }
                    default:
                        break
                    }
                }
            }

            try await session.connect { [weak self] in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.delegate?.whepClientDisconnected(
                        cameraId: self.cameraId,
                        reason: String(localized: "WHEP disconnected")
                    )
                }
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.delegate?.whepClientErrorToast(title: "WHEP connect failed: \(error)")
                self.delegate?.whepClientDisconnected(cameraId: self.cameraId, reason: "\(error)")
            }
            await stopInternal()
        }
    }

    private func stopInternal() async {
        readyStateTask?.cancel()
        readyStateTask = nil
        didReportConnected = false

        do {
            try await session?.close()
        } catch {
            // Best effort close.
        }

        if let rtcStream {
            await rtcStream.removeAllOutputs()
        }
        self.rtcStream = nil
        self.session = nil
        _ = latency // keep for potential future reconnect jitter logic
    }
}

