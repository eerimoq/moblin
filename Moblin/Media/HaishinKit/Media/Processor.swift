import AVFoundation
import UIKit

protocol ProcessorDelegate: AnyObject {
    func stream(audioLevel: Float, numberOfAudioChannels: Int, sampleRate: Double)
    func streamVideo(presentationTimestamp: Double)
    func streamVideo(failedEffect: String?)
    func streamVideo(lowFpsImage: Data?, frameNumber: UInt64)
    func streamVideo(findVideoFormatError: String, activeFormat: String)
    func streamVideoAttachCameraError()
    func streamVideoCaptureSessionError(_ message: String)
    func streamRecorderInitSegment(data: Data)
    func streamRecorderDataSegment(segment: RecorderDataSegment)
    func streamRecorderFinished()
    func streamAudio(sampleBuffer: CMSampleBuffer)
    func streamNoTorch()
    func streamSetZoomX(x: Float)
    func streamSetExposureBias(bias: Float)
    func streamSelectedFps(fps: Double, auto: Bool)
}

let mixerLockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.Mixer", qos: .userInteractive)
let netStreamLockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.NetStream.lock")

private class Stream {
    weak var delegate: (any AudioCodecDelegate & VideoEncoderDelegate)?

    init(delegate: (any AudioCodecDelegate & VideoEncoderDelegate)? = nil) {
        self.delegate = delegate
    }
}

final class Processor {
    let audio = AudioUnit()
    let video = VideoUnit()
    let recorder = Recorder()
    private var streams: [Stream] = []
    weak var delegate: (any ProcessorDelegate)?

    init() {
        audio.processor = self
        video.processor = self
        recorder.delegate = self
    }

    func setDelegate(delegate: ProcessorDelegate) {
        self.delegate = delegate
    }

    func setTorch(value: Bool) {
        netStreamLockQueue.async {
            self.video.torch = value
        }
    }

    func setFps(value: Float64, preferAutoFps: Bool) {
        netStreamLockQueue.async {
            self.video.setFps(fps: value, preferAutoFps: preferAutoFps)
        }
    }

    func getFps() -> Double {
        return video.getFps()
    }

    func setColorSpace(colorSpace: AVCaptureColorSpace, onComplete: @escaping () -> Void) {
        netStreamLockQueue.async {
            self.video.setColorSpace(colorSpace: colorSpace)
            onComplete()
        }
    }

    func setVideoSize(capture: CGSize, output: CGSize) {
        netStreamLockQueue.async {
            self.video.setSize(capture: capture, output: output)
        }
    }

    func setVideoOrientation(value: AVCaptureVideoOrientation) {
        netStreamLockQueue.async {
            self.video.videoOrientation = value
        }
    }

    func setHasAudio(value: Bool) {
        netStreamLockQueue.async {
            self.audio.muted = !value
        }
    }

    func setAudioEncoderSettings(settings: AudioEncoderSettings) {
        netStreamLockQueue.async {
            self.audio.getEncoders().first!.setSettings(settings: settings)
        }
    }

    func setVideoEncoderSettings(settings: VideoEncoderSettings) {
        netStreamLockQueue.async {
            self.video.getEncoders().first!.settings.mutate { $0 = settings }
        }
    }

    func attachCamera(
        params: VideoUnitAttachParams,
        onError: ((_ error: Error) -> Void)? = nil,
        onSuccess: (() -> Void)? = nil
    ) {
        netStreamLockQueue.async {
            do {
                try self.attachCameraInternal(params: params)
                onSuccess?()
            } catch {
                onError?(error)
            }
        }
    }

    func attachAudio(params: AudioUnitAttachParams, onError: ((_ error: Error) -> Void)? = nil) {
        netStreamLockQueue.async {
            do {
                try self.attachAudioInternal(params: params)
            } catch {
                onError?(error)
            }
        }
    }

    func setCameraControls(enabled: Bool) {
        netStreamLockQueue.async {
            self.video.setCameraControl(enabled: enabled)
        }
    }

    func addBufferedVideo(cameraId: UUID, name: String, latency: Double) {
        video.addBufferedVideo(cameraId: cameraId, name: name, latency: latency)
    }

    func removeBufferedVideo(cameraId: UUID) {
        video.removeBufferedVideo(cameraId: cameraId)
    }

    func appendBufferedVideoSampleBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        video.appendBufferedVideoSampleBuffer(cameraId: cameraId, sampleBuffer)
    }

    func setBufferedVideoTargetLatency(cameraId: UUID, _ latency: Double) {
        video.setBufferedVideoTargetLatency(cameraId: cameraId, latency: latency)
    }

    func addBufferedAudio(cameraId: UUID, name: String, latency: Double) {
        audio.addBufferedAudio(cameraId: cameraId, name: name, latency: latency)
    }

    func removeBufferedAudio(cameraId: UUID) {
        audio.removeBufferedAudio(cameraId: cameraId)
    }

    func appendBufferedAudioSampleBuffer(cameraId: UUID, _ sampleBuffer: CMSampleBuffer) {
        audio.appendBufferedAudioSampleBuffer(cameraId: cameraId, sampleBuffer)
    }

    func setBufferedAudioTargetLatency(cameraId: UUID, _ latency: Double) {
        audio.setBufferedAudioTargetLatency(cameraId: cameraId, latency: latency)
    }

    func registerVideoEffect(_ effect: VideoEffect) {
        video.registerEffect(effect)
    }

    func registerVideoEffectBack(_ effect: VideoEffect) {
        video.registerEffectBack(effect)
    }

    func unregisterVideoEffect(_ effect: VideoEffect) {
        video.unregisterEffect(effect)
    }

    func setPendingAfterAttachEffects(effects: [VideoEffect], rotation: Double) {
        video.setPendingAfterAttachEffects(effects: effects, rotation: rotation)
    }

    func usePendingAfterAttachEffects() {
        video.usePendingAfterAttachEffects()
    }

    func setLowFpsImage(fps: Float) {
        video.setLowFpsImage(fps: fps)
    }

    func setSceneSwitchTransition(sceneSwitchTransition: SceneSwitchTransition) {
        video.setSceneSwitchTransition(sceneSwitchTransition: sceneSwitchTransition)
    }

    func takeSnapshot(age: Float, onComplete: @escaping (UIImage, CIImage) -> Void) {
        video.takeSnapshot(age: age, onComplete: onComplete)
    }

    func setCleanRecordings(enabled: Bool) {
        video.setCleanRecordings(enabled: enabled)
    }

    func setCleanSnapshots(enabled: Bool) {
        video.setCleanSnapshots(enabled: enabled)
    }

    func setCleanExternalDisplay(enabled: Bool) {
        video.setCleanExternalDisplay(enabled: enabled)
    }

    func setAudioChannelsMap(map: [Int: Int]) {
        recorder.setAudioChannelsMap(map: map)
    }

    func setSpeechToText(enabled: Bool) {
        audio.setSpeechToText(enabled: enabled)
    }

    func startRecording(url: URL?, replay: Bool, audioSettings: [String: Any], videoSettings: [String: Any]) {
        recorder.startRunning(
            url: url,
            replay: replay,
            audioOutputSettings: audioSettings,
            videoOutputSettings: videoSettings
        )
    }

    func stopRecording() {
        recorder.stopRunning()
    }

    func setUrl(url: URL?) {
        recorder.setUrl(url: url)
    }

    func setReplayBuffering(enabled: Bool) {
        recorder.setReplayBuffering(enabled: enabled)
    }

    func stopMixer() {
        netStreamLockQueue.async {
            self.stopRunning()
        }
    }

    func startEncoding(_ delegate: any AudioCodecDelegate & VideoEncoderDelegate) {
        streams.append(Stream(delegate: delegate))
        video.startEncoding(self)
        audio.startEncoding(self)
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

    func setDrawable(drawable: PreviewView?) {
        video.drawable = drawable
    }

    func setExternalDisplayDrawable(drawable: PreviewView?) {
        video.externalDisplayDrawable = drawable
    }

    func getAudioEncoders() -> [AudioEncoder] {
        return audio.getEncoders()
    }

    func getVideoEncoders() -> [VideoEncoder] {
        return video.getEncoders()
    }

    func setBufferedAudioDrift(cameraId: UUID, drift: Double) {
        audio.setBufferedAudioDrift(cameraId: cameraId, drift: drift)
    }

    func setBufferedVideoDrift(cameraId: UUID, drift: Double) {
        video.setBufferedVideoDrift(cameraId: cameraId, drift: drift)
    }

    private func attachCameraInternal(params: VideoUnitAttachParams) throws {
        try video.attach(params: params)
    }

    private func attachAudioInternal(params: AudioUnitAttachParams) throws {
        try audio.attach(params: params)
    }
}

extension Processor: AudioCodecDelegate {
    func audioCodecOutputFormat(_ format: AVAudioFormat) {
        for stream in streams {
            stream.delegate?.audioCodecOutputFormat(format)
        }
    }

    func audioCodecOutputBuffer(_ buffer: AVAudioBuffer, _ presentationTimeStamp: CMTime) {
        for stream in streams {
            stream.delegate?.audioCodecOutputBuffer(buffer, presentationTimeStamp)
        }
    }
}

extension Processor: VideoEncoderDelegate {
    func videoEncoderOutputFormat(_ codec: VideoEncoder, _ formatDescription: CMFormatDescription) {
        for stream in streams {
            stream.delegate?.videoEncoderOutputFormat(codec, formatDescription)
        }
    }

    func videoEncoderOutputSampleBuffer(_ codec: VideoEncoder, _ sampleBuffer: CMSampleBuffer) {
        for stream in streams {
            stream.delegate?.videoEncoderOutputSampleBuffer(codec, sampleBuffer)
        }
    }
}

extension Processor: RecorderDelegate {
    func recorderInitSegment(data: Data) {
        delegate?.streamRecorderInitSegment(data: data)
    }

    func recorderDataSegment(segment: RecorderDataSegment) {
        delegate?.streamRecorderDataSegment(segment: segment)
    }

    func recorderFinished() {
        delegate?.streamRecorderFinished()
    }
}
