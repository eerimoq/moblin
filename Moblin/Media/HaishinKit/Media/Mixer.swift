import AVFoundation
import SwiftUI

let mixerLockQueue = DispatchQueue(
    label: "com.haishinkit.HaishinKit.Mixer",
    qos: .userInteractive
)

func makeCaptureSession() -> AVCaptureSession {
    let session = AVCaptureSession()
    if session.isMultitaskingCameraAccessSupported {
        session.isMultitaskingCameraAccessEnabled = true
    }
    return session
}

protocol MixerDelegate: AnyObject {
    func mixer(audioLevel: Float, numberOfAudioChannels: Int)
    func mixerVideo(presentationTimestamp: Double)
    func mixerVideo(failedEffect: String?)
    func mixerVideo(lowFpsImage: Data?, frameNumber: UInt64)
    func mixerRecorderFinished()
    func mixerRecorderError()
    func mixer(findVideoFormatError: String, activeFormat: String)
    func mixer(audioSampleBuffer: CMSampleBuffer)
    func mixerNoTorch()
    func mixerSetZoomX(x: Float)
    func mixerSetExposureBias(bias: Float)
    func mixerSelectedFps(fps: Double, auto: Bool)
}

class Mixer {
    weak var delegate: (any MixerDelegate)?

    let audio = AudioUnit()
    let video = VideoUnit()
    let recorder = Recorder()

    init() {
        audio.mixer = self
        video.mixer = self
        recorder.delegate = self
    }

    func attachCamera(
        _ device: AVCaptureDevice?,
        _ cameraPreviewLayer: AVCaptureVideoPreviewLayer?,
        _ showCameraPreview: Bool,
        _ replaceVideo: UUID?,
        _ preferredVideoStabilizationMode: AVCaptureVideoStabilizationMode,
        _ isVideoMirrored: Bool,
        _ ignoreFramesAfterAttachSeconds: Double
    ) throws {
        try video.attach(
            device,
            cameraPreviewLayer,
            showCameraPreview,
            replaceVideo,
            preferredVideoStabilizationMode,
            isVideoMirrored,
            ignoreFramesAfterAttachSeconds
        )
    }

    func attachAudio(_ device: AVCaptureDevice?, _ replaceAudio: UUID?) throws {
        try audio.attach(device, replaceAudio)
    }

    func startEncoding(_ delegate: any AudioCodecDelegate & VideoEncoderDelegate) {
        video.startEncoding(delegate)
        audio.startEncoding(delegate)
    }

    func stopEncoding() {
        video.stopEncoding()
        audio.stopEncoding()
    }

    func startRunning() {
        video.startRunning()
        audio.startRunning()
    }

    func stopRunning() {
        video.stopRunning()
        audio.stopRunning()
    }

    func setReplaceAudioDrift(cameraId: UUID, drift: Double) {
        audio.setReplaceAudioDrift(cameraId: cameraId, drift: drift)
    }

    func setReplaceVideoDrift(cameraId: UUID, drift: Double) {
        video.setReplaceVideoDrift(cameraId: cameraId, drift: drift)
    }
}

extension Mixer: IORecorderDelegate {
    func recorderFinished() {
        delegate?.mixerRecorderFinished()
    }

    func recorderError() {
        delegate?.mixerRecorderError()
    }
}
