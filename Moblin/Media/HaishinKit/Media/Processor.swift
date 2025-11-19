import AVFoundation
import UIKit

protocol ProcessorDelegate: AnyObject {
    func stream(audioLevel: Float, numberOfAudioChannels: Int, sampleRate: Double)
    func streamVideo(failedEffect: String?)
    func streamVideo(lowFpsImage: Data?, frameNumber: UInt64)
    func streamVideo(findVideoFormatError: String, activeFormat: String)
    func streamVideoAttachCameraError()
    func streamVideoCaptureSessionError(_ message: String)
    func streamVideoBufferedVideoReady(cameraId: UUID)
    func streamVideoBufferedVideoRemoved(cameraId: UUID)
    func streamVideoFps(fps: Int)
    func streamVideoEncoderResolution(resolution: CGSize)
    func streamRecorderInitSegment(data: Data)
    func streamRecorderDataSegment(segment: RecorderDataSegment)
    func streamRecorderFinished()
    func streamAudio(sampleBuffer: CMSampleBuffer)
    func streamNoTorch()
    func streamSetZoomX(x: Float)
    func streamSetExposureBias(bias: Float)
    func streamSelectedFps(auto: Bool)
}

let processorControlQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.Processor.Control")
let processorPipelineQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.Processor.Pipeline", qos: .userInteractive)

private class Stream {
    weak var delegate: (any AudioEncoderDelegate & VideoEncoderDelegate)?

    init(delegate: (any AudioEncoderDelegate & VideoEncoderDelegate)? = nil) {
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
        processorControlQueue.async {
            self.video.torch = value
        }
    }

    func setFps(value: Float64, preferAutoFps: Bool) {
        processorControlQueue.async {
            self.video.setFps(fps: value, preferAutoFps: preferAutoFps)
        }
    }

    func getFps() -> Double {
        return video.getFps()
    }

    func setColorSpace(colorSpace: AVCaptureColorSpace, onComplete: @escaping () -> Void) {
        processorControlQueue.async {
            self.video.setColorSpace(colorSpace: colorSpace)
            onComplete()
        }
    }

    func setVideoSize(capture: CGSize, canvas: CGSize) {
        processorControlQueue.async {
            self.video.setSize(capture: capture, canvas: canvas)
        }
    }

    func setVideoOrientation(value: AVCaptureVideoOrientation) {
        processorControlQueue.async {
            self.video.videoOrientation = value
        }
    }

    func setHasAudio(value: Bool) {
        processorControlQueue.async {
            self.audio.muted = !value
        }
    }

    func setAudioEncoderSettings(settings: AudioEncoderSettings) {
        audio.encoder.setSettings(settings: settings)
    }

    func setVideoEncoderSettings(settings: VideoEncoderSettings) {
        video.encoder.settings.mutate { $0 = settings }
    }

    func attachCamera(
        params: VideoUnitAttachParams,
        onError: ((_ error: Error) -> Void)? = nil,
        onSuccess: (() -> Void)? = nil
    ) {
        processorControlQueue.async {
            do {
                try self.attachCameraInternal(params: params)
                onSuccess?()
            } catch {
                onError?(error)
            }
        }
    }

    func attachAudio(params: AudioUnitAttachParams, onError: ((_ error: Error) -> Void)? = nil) {
        processorControlQueue.async {
            do {
                try self.attachAudioInternal(params: params)
            } catch {
                onError?(error)
            }
        }
    }

    func setCameraControls(enabled: Bool) {
        processorControlQueue.async {
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

    func setScreenPreview(enabled: Bool) {
        video.setScreenPreview(enabled: enabled)
    }

    func setLowFpsImage(fps: Float) {
        video.setLowFpsImage(fps: fps)
    }

    func setSceneSwitchTransition(sceneSwitchTransition: SceneSwitchTransition) {
        video.setSceneSwitchTransition(sceneSwitchTransition: sceneSwitchTransition)
    }

    func takeSnapshot(age: Float, onComplete: @escaping (UIImage, CIImage, CIImage) -> Void) {
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

    func stop() {
        processorControlQueue.async {
            self.stopRunning()
        }
    }

    func startEncoding(_ delegate: any AudioEncoderDelegate & VideoEncoderDelegate) {
        streams.append(Stream(delegate: delegate))
        logger.info("processor: Starting encoding")
        video.startEncoding(self)
        audio.startEncoding(self)
    }

    func stopEncoding(_ delegate: any AudioEncoderDelegate & VideoEncoderDelegate) {
        streams.removeAll(where: { $0.delegate === delegate })
        if streams.isEmpty {
            logger.info("processor: Stopping encoding")
            video.stopEncoding()
            audio.stopEncoding()
        }
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

    func getAudioEncoder() -> AudioEncoder {
        return audio.encoder
    }

    func getVideoEncoder() -> VideoEncoder {
        return video.encoder
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

extension Processor: AudioEncoderDelegate {
    func audioEncoderOutputFormat(_ format: AVAudioFormat) {
        for stream in streams {
            stream.delegate?.audioEncoderOutputFormat(format)
        }
    }

    func audioEncoderOutputBuffer(_ buffer: AVAudioCompressedBuffer, _ presentationTimeStamp: CMTime) {
        for stream in streams {
            stream.delegate?.audioEncoderOutputBuffer(buffer, presentationTimeStamp)
        }
    }
}

extension Processor: VideoEncoderDelegate {
    func videoEncoderOutputFormat(_ encoder: VideoEncoder, _ formatDescription: CMFormatDescription) {
        for stream in streams {
            stream.delegate?.videoEncoderOutputFormat(encoder, formatDescription)
        }
    }

    func videoEncoderOutputSampleBuffer(_ encoder: VideoEncoder,
                                        _ sampleBuffer: CMSampleBuffer,
                                        _ decodeTimeStampOffset: CMTime)
    {
        for stream in streams {
            stream.delegate?.videoEncoderOutputSampleBuffer(encoder, sampleBuffer, decodeTimeStampOffset)
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
