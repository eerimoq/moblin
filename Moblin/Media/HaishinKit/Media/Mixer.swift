import AVFoundation

let mixerLockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.Mixer", qos: .userInteractive)

class Mixer {
    weak var delegate: (any MediaProcessorDelegate)?
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

    func attachAudio(params: AudioUnitAttachParams) throws {
        try audio.attach(params: params)
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
        delegate?.streamRecorderInitSegment(data: data)
    }

    func recorderDataSegment(segment: RecorderDataSegment) {
        delegate?.streamRecorderDataSegment(segment: segment)
    }

    func recorderFinished() {
        delegate?.streamRecorderFinished()
    }
}
