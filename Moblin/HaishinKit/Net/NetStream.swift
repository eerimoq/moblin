import AVFoundation
import CoreImage
import CoreMedia
import UIKit

protocol NetStreamDelegate: AnyObject {
    func stream(
        _ stream: NetStream,
        sessionWasInterrupted session: AVCaptureSession,
        reason: AVCaptureSession.InterruptionReason?
    )
    func stream(_ stream: NetStream, sessionInterruptionEnded session: AVCaptureSession)
    func streamDidOpen(_ stream: NetStream)
    func stream(
        _ stream: NetStream,
        audioLevel: Float,
        numberOfAudioChannels: Int,
        presentationTimestamp: Double
    )
    func streamVideo(_ stream: NetStream, presentationTimestamp: Double)
    func streamVideo(_ stream: NetStream, failedEffect: String?)
    func streamVideo(_ stream: NetStream, lowFpsImage: Data?)
    func stream(_ stream: NetStream, recorderFinishWriting writer: AVAssetWriter)
}

open class NetStream: NSObject {
    let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.NetStream.lock")
    let mixer = Mixer()
    weak var delegate: (any NetStreamDelegate)?

    override init() {
        super.init()
        mixer.delegate = self
    }

    func setTorch(value: Bool) {
        lockQueue.async {
            self.mixer.video.torch = value
        }
    }

    func setFrameRate(value: Float64) {
        lockQueue.async {
            self.mixer.video.frameRate = value
        }
    }

    func setColorSpace(colorSpace: AVCaptureColorSpace, onComplete: @escaping () -> Void) {
        lockQueue.async {
            self.mixer.video.colorSpace = colorSpace
            onComplete()
        }
    }

    func setSessionPreset(preset: AVCaptureSession.Preset) {
        lockQueue.async {
            self.mixer.sessionPreset = preset
        }
    }

    func setVideoOrientation(value: AVCaptureVideoOrientation) {
        mixer.video.videoOrientation = value
    }

    func setHasAudio(value: Bool) {
        lockQueue.async {
            self.mixer.audio.muted = !value
        }
    }

    func getHistograms() -> (Histogram, Histogram) {
        return mixer.video.getHistograms()
    }

    var audioSettings: AudioCodecOutputSettings {
        get {
            mixer.audio.codec.outputSettings
        }
        set {
            mixer.audio.codec.outputSettings = newValue
        }
    }

    var videoSettings: VideoCodecSettings {
        get {
            mixer.video.codec.settings
        }
        set {
            mixer.video.codec.settings = newValue
        }
    }

    func attachCamera(
        _ device: AVCaptureDevice?,
        onError: ((_ error: Error) -> Void)? = nil,
        onSuccess: (() -> Void)? = nil,
        replaceVideoCameraId: UUID? = nil
    ) {
        lockQueue.async {
            do {
                try self.mixer.attachCamera(device, replaceVideoCameraId)
                onSuccess?()
            } catch {
                onError?(error)
            }
        }
    }

    func attachAudio(
        _ device: AVCaptureDevice?,
        onError: ((_ error: Error) -> Void)? = nil,
        replaceAudioId: UUID? = nil
    ) {
        lockQueue.async {
            do {
                try self.mixer.attachAudio(device, replaceAudioId)
            } catch {
                onError?(error)
            }
        }
    }

    func addReplaceVideoSampleBuffer(id: UUID, _ sampleBuffer: CMSampleBuffer) {
        mixer.video.addReplaceVideoSampleBuffer(id: id, sampleBuffer)
    }

    func addAudioPCMBuffer(id: UUID, _ audioBuffer: AVAudioPCMBuffer) {
        mixer.audio.addReplaceAudioPCMBuffer(id: id, audioBuffer)
    }

    func addReplaceVideo(cameraId: UUID, latency: Double) {
        mixer.video.addReplaceVideo(cameraId: cameraId, latency: latency)
    }

    func addReplaceAudio(cameraId: UUID) {
        mixer.audio.addReplaceAudio(cameraId: cameraId)
    }

    func removeReplaceVideo(cameraId: UUID) {
        mixer.video.removeReplaceVideo(cameraId: cameraId)
    }

    func removeReplaceAudio(cameraId: UUID) {
        mixer.audio.removeReplaceAudio(cameraId: cameraId)
    }

    func videoCapture() -> VideoUnit? {
        return mixer.video
    }

    func registerVideoEffect(_ effect: VideoEffect) {
        mixer.video.registerEffect(effect)
    }

    func unregisterVideoEffect(_ effect: VideoEffect) {
        mixer.video.unregisterEffect(effect)
    }

    func setPendingAfterAttachEffects(effects: [VideoEffect]) {
        mixer.video.setPendingAfterAttachEffects(effects: effects)
    }

    func usePendingAfterAttachEffects() {
        mixer.video.usePendingAfterAttachEffects()
    }

    func setLowFpsImage(enabled: Bool) {
        mixer.video.setLowFpsImage(enabled: enabled)
    }

    func setAudioChannelsMap(map: [Int: Int]) {
        audioSettings.channelsMap = map
        mixer.recorder.setAudioChannelsMap(map: map)
    }

    func startRecording(
        url: URL,
        audioSettings: [String: Any],
        videoSettings: [String: Any]
    ) {
        mixer.recorder.url = url
        mixer.recorder.audioOutputSettings = audioSettings
        mixer.recorder.videoOutputSettings = videoSettings
        mixer.recorder.startRunning()
    }

    func stopRecording() {
        mixer.recorder.stopRunning()
    }
}

extension NetStream: MixerDelegate {
    func mixer(
        sessionWasInterrupted session: AVCaptureSession,
        reason: AVCaptureSession.InterruptionReason?
    ) {
        delegate?.stream(self, sessionWasInterrupted: session, reason: reason)
    }

    func mixer(sessionInterruptionEnded session: AVCaptureSession) {
        delegate?.stream(self, sessionInterruptionEnded: session)
    }

    func mixer(audioLevel: Float, numberOfAudioChannels: Int, presentationTimestamp: Double) {
        delegate?.stream(
            self,
            audioLevel: audioLevel,
            numberOfAudioChannels: numberOfAudioChannels,
            presentationTimestamp: presentationTimestamp
        )
    }

    func mixerVideo(presentationTimestamp: Double) {
        delegate?.streamVideo(self, presentationTimestamp: presentationTimestamp)
    }

    func mixerVideo(failedEffect: String?) {
        delegate?.streamVideo(self, failedEffect: failedEffect)
    }

    func mixerVideo(lowFpsImage: Data?) {
        delegate?.streamVideo(self, lowFpsImage: lowFpsImage)
    }

    func mixer(recorderFinishWriting writer: AVAssetWriter) {
        delegate?.stream(self, recorderFinishWriting: writer)
    }
}
