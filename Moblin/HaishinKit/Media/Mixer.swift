import AVFoundation
import SwiftUI

private func makeCaptureSession() -> AVCaptureSession {
    let session = AVCaptureSession()
    if #available(iOS 16.0, *) {
        if session.isMultitaskingCameraAccessSupported {
            session.isMultitaskingCameraAccessEnabled = true
        }
    }
    return session
}

protocol MixerDelegate: AnyObject {
    func mixer(audioLevel: Float, numberOfAudioChannels: Int, presentationTimestamp: Double)
    func mixerVideo(presentationTimestamp: Double)
    func mixerVideo(failedEffect: String?)
    func mixerVideo(lowFpsImage: Data?)
    func mixer(recorderFinishWriting writer: AVAssetWriter)
    func mixer(findVideoFormatError: String, activeFormat: String)
}

/// An object that mixies audio and video for streaming.
class Mixer {
    static let defaultFrameRate: Float64 = 30

    var sessionPreset: AVCaptureSession.Preset = .hd1280x720
    let videoSession = makeCaptureSession()
    let audioSession = makeCaptureSession()
    private(set) var isRunning: Atomic<Bool> = .init(false)
    private var isEncoding = false

    weak var delegate: (any MixerDelegate)?
    private var videoTimeStamp = CMTime.zero

    let audio = AudioUnit()
    let video = VideoUnit()
    let recorder = Recorder()

    init() {
        audio.mixer = self
        video.mixer = self
        recorder.delegate = self
    }

    deinit {
        if videoSession.isRunning {
            videoSession.stopRunning()
        }
        if audioSession.isRunning {
            audioSession.stopRunning()
        }
    }

    func attachCamera(_ device: AVCaptureDevice?, _ replaceVideo: UUID?) throws {
        try video.attach(device, replaceVideo)
    }

    func attachAudio(_ device: AVCaptureDevice?, _ replaceAudio: UUID?) throws {
        try audio.attach(device, replaceAudio)
    }

    func useSampleBuffer(_ presentationTimeStamp: CMTime, mediaType: AVMediaType) -> Bool {
        if mediaType == .audio {
            return !videoTimeStamp.seconds.isZero && videoTimeStamp.seconds <= presentationTimeStamp
                .seconds
        }
        if videoTimeStamp == CMTime.zero {
            videoTimeStamp = presentationTimeStamp
        }
        return true
    }

    func startEncoding(_ delegate: any AudioCodecDelegate & VideoCodecDelegate) {
        guard !isEncoding else {
            return
        }
        isEncoding = true
        video.startEncoding(delegate)
        audio.startEncoding(delegate)
    }

    func stopEncoding() {
        guard isEncoding else {
            return
        }
        videoTimeStamp = CMTime.zero
        video.stopEncoding()
        audio.stopEncoding()
        isEncoding = false
    }

    func startRunning() {
        guard !isRunning.value else {
            return
        }
        videoSession.startRunning()
        audioSession.startRunning()
        isRunning.mutate { $0 = audioSession.isRunning }
    }

    func stopRunning() {
        guard isRunning.value else {
            return
        }
        videoSession.stopRunning()
        audioSession.stopRunning()
        isRunning.mutate { $0 = audioSession.isRunning }
    }
}

extension Mixer: IORecorderDelegate {
    func recorder(_: Recorder, finishWriting writer: AVAssetWriter) {
        delegate?.mixer(recorderFinishWriting: writer)
    }
}
