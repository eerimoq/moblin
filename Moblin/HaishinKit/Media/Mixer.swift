import AVFoundation
import SwiftUI

func makeCaptureSession() -> AVCaptureSession {
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
    func mixerVideo(lowFpsImage: Data?, frameNumber: UInt64)
    func mixer(recorderFinishWriting writer: AVAssetWriter)
    func mixer(findVideoFormatError: String, activeFormat: String)
}

/// An object that mixies audio and video for streaming.
class Mixer {
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
        if video.session.isRunning {
            video.session.stopRunning()
        }
        if audio.session.isRunning {
            audio.session.stopRunning()
        }
    }

    func attachCamera(_ device: AVCaptureDevice?) throws {
        try video.attach(device)
    }
    
    func attachReplaceCamera(_ replaceVideo: UUID?) throws {
        try video.attachReplace(replaceVideo)
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
        video.startRunning()
        audio.startRunning()
        isRunning.mutate { $0 = audio.session.isRunning }
    }

    func stopRunning() {
        guard isRunning.value else {
            return
        }
        video.stopRunning()
        audio.stopRunning()
        isRunning.mutate { $0 = audio.session.isRunning }
    }
}

extension Mixer: IORecorderDelegate {
    func recorder(_: Recorder, finishWriting writer: AVAssetWriter) {
        delegate?.mixer(recorderFinishWriting: writer)
    }
}
