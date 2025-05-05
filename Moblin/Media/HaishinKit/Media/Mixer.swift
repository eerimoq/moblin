import AVFoundation

let mixerLockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.Mixer", qos: .userInteractive)

protocol MixerDelegate: AnyObject {
    func mixer(audioLevel: Float, numberOfAudioChannels: Int)
    func mixerVideo(presentationTimestamp: Double)
    func mixerVideo(failedEffect: String?)
    func mixerVideo(lowFpsImage: Data?, frameNumber: UInt64)
    func mixerRecorderInitSegment(data: Data)
    func mixerRecorderDataSegment(segment: RecorderDataSegment)
    func mixerRecorderFinished()
    func mixer(findVideoFormatError: String, activeFormat: String)
    func mixerAttachCameraError()
    func mixerCaptureSessionError(message: String)
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

    func attachCamera(params: VideoUnitAttachParams) throws {
        try video.attach(params: params)
    }

    func attachAudio(_ device: AVCaptureDevice?, _ bufferedAudio: UUID?) throws {
        try audio.attach(device, bufferedAudio)
    }

    func startRunning() {
        video.startRunning()
        audio.startRunning()
    }

    func stopRunning() {
        video.stopRunning()
        audio.stopRunning()
    }

    func startEncoding(_ delegate: any AudioCodecDelegate & VideoEncoderDelegate) {
        video.startEncoding(delegate)
        audio.startEncoding(delegate)
    }

    func stopEncoding() {
        video.stopEncoding()
        audio.stopEncoding()
    }

    func setBufferedAudioDrift(cameraId: UUID, drift: Double) {
        audio.setBufferedAudioDrift(cameraId: cameraId, drift: drift)
    }

    func setBufferedVideoDrift(cameraId: UUID, drift: Double) {
        video.setBufferedVideoDrift(cameraId: cameraId, drift: drift)
    }
}

extension Mixer: RecorderDelegate {
    func recorderInitSegment(data: Data) {
        delegate?.mixerRecorderInitSegment(data: data)
    }

    func recorderDataSegment(segment: RecorderDataSegment) {
        delegate?.mixerRecorderDataSegment(segment: segment)
    }

    func recorderFinished() {
        delegate?.mixerRecorderFinished()
    }
}
