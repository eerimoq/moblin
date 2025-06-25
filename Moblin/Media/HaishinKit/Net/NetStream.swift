import AVFoundation
import UIKit

protocol NetStreamDelegate: AnyObject {
    func stream(_ stream: NetStream, audioLevel: Float, numberOfAudioChannels: Int)
    func streamVideo(_ stream: NetStream, presentationTimestamp: Double)
    func streamVideo(_ stream: NetStream, failedEffect: String?)
    func streamVideo(_ stream: NetStream, lowFpsImage: Data?, frameNumber: UInt64)
    func streamVideo(_ stream: NetStream, findVideoFormatError: String, activeFormat: String)
    func streamVideoAttachCameraError(_ stream: NetStream)
    func streamVideoCaptureSessionError(_ stream: NetStream, _ message: String)
    func streamRecorderInitSegment(data: Data)
    func streamRecorderDataSegment(segment: RecorderDataSegment)
    func streamRecorderFinished()
    func streamAudio(_ stream: NetStream, sampleBuffer: CMSampleBuffer)
    func streamNoTorch()
    func streamSetZoomX(x: Float)
    func streamSetExposureBias(bias: Float)
    func streamSelectedFps(fps: Double, auto: Bool)
}

let netStreamLockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.NetStream.lock")

open class NetStream: NSObject {
    let mixer = Mixer()
    weak var delegate: (any NetStreamDelegate)?

    override init() {
        super.init()
        mixer.delegate = self
    }

    func setTorch(value: Bool) {
        netStreamLockQueue.async {
            self.mixer.video.torch = value
        }
    }

    func setFrameRate(value: Float64) {
        netStreamLockQueue.async {
            self.mixer.video.frameRate = value
        }
    }

    func setPreferFrameRate(value: Bool) {
        netStreamLockQueue.async {
            self.mixer.video.preferAutoFrameRate = value
        }
    }

    func setColorSpace(colorSpace: AVCaptureColorSpace, onComplete: @escaping () -> Void) {
        netStreamLockQueue.async {
            self.mixer.video.colorSpace = colorSpace
            onComplete()
        }
    }

    func setVideoSize(capture: CGSize, output: CGSize) {
        netStreamLockQueue.async {
            self.mixer.video.setCaptureSize(size: capture)
            self.mixer.video.setOutputSize(size: output)
        }
    }

    func setVideoOrientation(value: AVCaptureVideoOrientation) {
        netStreamLockQueue.async {
            self.mixer.video.videoOrientation = value
        }
    }

    func setHasAudio(value: Bool) {
        netStreamLockQueue.async {
            self.mixer.audio.muted = !value
        }
    }

    func setAudioEncoderSettings(settings: AudioEncoderSettings) {
        netStreamLockQueue.async {
            self.mixer.audio.getEncoders().first!.setSettings(settings: settings)
        }
    }

    func setVideoEncoderSettings(settings: VideoEncoderSettings) {
        netStreamLockQueue.async {
            self.mixer.video.getEncoders().first!.settings.mutate { $0 = settings }
        }
    }

    func attachCamera(
        params: VideoUnitAttachParams,
        onError: ((_ error: Error) -> Void)? = nil,
        onSuccess: (() -> Void)? = nil
    ) {
        netStreamLockQueue.async {
            do {
                try self.mixer.attachCamera(params: params)
                onSuccess?()
            } catch {
                onError?(error)
            }
        }
    }

    func attachAudio(params: AudioUnitAttachParams, onError: ((_ error: Error) -> Void)? = nil) {
        netStreamLockQueue.async {
            do {
                try self.mixer.attachAudio(params: params)
            } catch {
                onError?(error)
            }
        }
    }

    func setCameraControls(enabled: Bool) {
        netStreamLockQueue.async {
            self.mixer.video.setCameraControl(enabled: enabled)
        }
    }

    func addBufferedVideo(cameraId: UUID, name: String, latency: Double) {
        mixer.video.addBufferedVideo(cameraId: cameraId, name: name, latency: latency)
    }

    func removeBufferedVideo(cameraId: UUID) {
        mixer.video.removeBufferedVideo(cameraId: cameraId)
    }

    func appendBufferedVideoSampleBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        mixer.video.appendBufferedVideoSampleBuffer(cameraId: cameraId, sampleBuffer)
    }

    func setBufferedVideoTargetLatency(cameraId: UUID, _ latency: Double) {
        mixer.video.setBufferedVideoTargetLatency(cameraId: cameraId, latency: latency)
    }

    func addBufferedAudio(cameraId: UUID, name: String, latency: Double) {
        mixer.audio.addBufferedAudio(cameraId: cameraId, name: name, latency: latency)
    }

    func removeBufferedAudio(cameraId: UUID) {
        mixer.audio.removeBufferedAudio(cameraId: cameraId)
    }

    func appendBufferedAudioSampleBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        mixer.audio.appendBufferedAudioSampleBuffer(cameraId: cameraId, sampleBuffer)
    }

    func setBufferedAudioTargetLatency(cameraId: UUID, _ latency: Double) {
        mixer.audio.setBufferedAudioTargetLatency(cameraId: cameraId, latency: latency)
    }

    func registerVideoEffect(_ effect: VideoEffect) {
        mixer.video.registerEffect(effect)
    }

    func registerVideoEffectBack(_ effect: VideoEffect) {
        mixer.video.registerEffectBack(effect)
    }

    func unregisterVideoEffect(_ effect: VideoEffect) {
        mixer.video.unregisterEffect(effect)
    }

    func setPendingAfterAttachEffects(effects: [VideoEffect], rotation: Double) {
        mixer.video.setPendingAfterAttachEffects(effects: effects, rotation: rotation)
    }

    func usePendingAfterAttachEffects() {
        mixer.video.usePendingAfterAttachEffects()
    }

    func setLowFpsImage(fps: Float) {
        mixer.video.setLowFpsImage(fps: fps)
    }

    func setSceneSwitchTransition(sceneSwitchTransition: SceneSwitchTransition) {
        mixer.video.setSceneSwitchTransition(sceneSwitchTransition: sceneSwitchTransition)
    }

    func takeSnapshot(age: Float, onComplete: @escaping (UIImage, CIImage) -> Void) {
        mixer.video.takeSnapshot(age: age, onComplete: onComplete)
    }

    func setCleanRecordings(enabled: Bool) {
        mixer.video.setCleanRecordings(enabled: enabled)
    }

    func setCleanSnapshots(enabled: Bool) {
        mixer.video.setCleanSnapshots(enabled: enabled)
    }

    func setCleanExternalDisplay(enabled: Bool) {
        mixer.video.setCleanExternalDisplay(enabled: enabled)
    }

    func setAudioChannelsMap(map: [Int: Int]) {
        mixer.recorder.setAudioChannelsMap(map: map)
    }

    func setSpeechToText(enabled: Bool) {
        mixer.audio.setSpeechToText(enabled: enabled)
    }

    func startRecording(url: URL?, replay: Bool, audioSettings: [String: Any], videoSettings: [String: Any]) {
        mixer.recorder.startRunning(
            url: url,
            replay: replay,
            audioOutputSettings: audioSettings,
            videoOutputSettings: videoSettings
        )
    }

    func stopRecording() {
        mixer.recorder.stopRunning()
    }

    func setUrl(url: URL?) {
        mixer.recorder.setUrl(url: url)
    }

    func setReplayBuffering(enabled: Bool) {
        mixer.recorder.setReplayBuffering(enabled: enabled)
    }

    func stopMixer() {
        netStreamLockQueue.async {
            self.mixer.stopRunning()
        }
    }
}

extension NetStream: MixerDelegate {
    func mixer(audioLevel: Float, numberOfAudioChannels: Int) {
        delegate?.stream(self, audioLevel: audioLevel, numberOfAudioChannels: numberOfAudioChannels)
    }

    func mixerVideo(presentationTimestamp: Double) {
        delegate?.streamVideo(self, presentationTimestamp: presentationTimestamp)
    }

    func mixerVideo(failedEffect: String?) {
        delegate?.streamVideo(self, failedEffect: failedEffect)
    }

    func mixerVideo(lowFpsImage: Data?, frameNumber: UInt64) {
        delegate?.streamVideo(self, lowFpsImage: lowFpsImage, frameNumber: frameNumber)
    }

    func mixer(findVideoFormatError: String, activeFormat: String) {
        delegate?.streamVideo(self, findVideoFormatError: findVideoFormatError, activeFormat: activeFormat)
    }

    func mixerAttachCameraError() {
        delegate?.streamVideoAttachCameraError(self)
    }

    func mixerCaptureSessionError(message: String) {
        delegate?.streamVideoCaptureSessionError(self, message)
    }

    func mixerRecorderInitSegment(data: Data) {
        delegate?.streamRecorderInitSegment(data: data)
    }

    func mixerRecorderDataSegment(segment: RecorderDataSegment) {
        delegate?.streamRecorderDataSegment(segment: segment)
    }

    func mixerRecorderFinished() {
        delegate?.streamRecorderFinished()
    }

    func mixer(audioSampleBuffer: CMSampleBuffer) {
        delegate?.streamAudio(self, sampleBuffer: audioSampleBuffer)
    }

    func mixerNoTorch() {
        delegate?.streamNoTorch()
    }

    func mixerSetZoomX(x: Float) {
        delegate?.streamSetZoomX(x: x)
    }

    func mixerSetExposureBias(bias: Float) {
        delegate?.streamSetExposureBias(bias: bias)
    }

    func mixerSelectedFps(fps: Double, auto: Bool) {
        delegate?.streamSelectedFps(fps: fps, auto: auto)
    }
}
