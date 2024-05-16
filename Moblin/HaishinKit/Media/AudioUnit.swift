import AVFoundation

private let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.AudioIOUnit.lock")

func makeChannelMap(
    numberOfInputChannels: Int,
    numberOfOutputChannels: Int,
    outputToInputChannelsMap: [Int: Int]
) -> [NSNumber] {
    var result = Array(repeating: -1, count: numberOfOutputChannels)
    for inputIndex in 0 ..< min(numberOfInputChannels, numberOfOutputChannels) {
        result[inputIndex] = inputIndex
    }
    for outputIndex in 0 ..< numberOfOutputChannels {
        if let inputIndex = outputToInputChannelsMap[outputIndex], inputIndex < numberOfInputChannels {
            result[outputIndex] = inputIndex
        }
    }
    return result.map { NSNumber(value: $0) }
}

private class ReplaceAudio {
    var nextPresentationTimeStamp: CMTime = .zero

    func createSampleBuffer(audioPCMBuffer: AVAudioPCMBuffer) -> CMSampleBuffer? {
        if nextPresentationTimeStamp == CMTime.zero {
            nextPresentationTimeStamp = CMClockGetTime(CMClockGetHostTimeClock())
        }
        guard let sampleBuffer = audioPCMBuffer
            .makeSampleBuffer(presentationTimeStamp: nextPresentationTimeStamp)
        else {
            return nil
        }
        nextPresentationTimeStamp = CMTimeAdd(
            nextPresentationTimeStamp,
            CMTime(
                value: CMTimeValue(Double(audioPCMBuffer.frameLength)),
                timescale: CMTimeScale(audioPCMBuffer.format.sampleRate)
            )
        )
        return sampleBuffer
    }
}

final class AudioUnit: NSObject {
    lazy var codec: AudioCodec = .init(lockQueue: lockQueue)
    private(set) var device: AVCaptureDevice?
    private var input: AVCaptureInput?
    private var output: AVCaptureAudioDataOutput?
    var muted = false
    weak var mixer: Mixer?
    private var selectedReplaceAudioId: UUID?
    private var replaceAudios: [UUID: ReplaceAudio] = [:]

    private var inputSourceFormat: AudioStreamBasicDescription? {
        didSet {
            guard inputSourceFormat != oldValue else {
                return
            }
            codec.inSourceFormat = inputSourceFormat
        }
    }

    func attach(_ device: AVCaptureDevice?, _ replaceAudio: UUID?) throws {
        lockQueue.sync {
            self.selectedReplaceAudioId = replaceAudio
        }
        guard let mixer else {
            return
        }
        let captureSession = mixer.audioSession
        output?.setSampleBufferDelegate(nil, queue: lockQueue)
        try attachDevice(device, captureSession)
        self.device = device
        output?.setSampleBufferDelegate(self, queue: lockQueue)
        captureSession.automaticallyConfiguresApplicationAudioSession = false
    }

    func appendSampleBuffer(
        _ sampleBuffer: CMSampleBuffer,
        _ presentationTimeStamp: CMTime,
        isFirstAfterAttach _: Bool
    ) {
        guard let sampleBuffer = sampleBuffer.muted(muted) else {
            return
        }
        inputSourceFormat = sampleBuffer.formatDescription?.streamBasicDescription?.pointee
        codec.appendSampleBuffer(sampleBuffer, presentationTimeStamp)
        mixer?.recorder.appendAudio(sampleBuffer)
    }

    func startEncoding(_ delegate: any AudioCodecDelegate & VideoCodecDelegate) {
        codec.delegate = delegate
        codec.startRunning()
    }

    func stopEncoding() {
        codec.stopRunning()
        codec.delegate = nil
        inputSourceFormat = nil
    }

    private func attachDevice(_ device: AVCaptureDevice?, _ captureSession: AVCaptureSession) throws {
        captureSession.beginConfiguration()
        defer {
            captureSession.commitConfiguration()
        }
        if let input, captureSession.inputs.contains(input) {
            captureSession.removeInput(input)
        }
        if let output, captureSession.outputs.contains(output) {
            captureSession.removeOutput(output)
        }
        if let device {
            input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input!) {
                captureSession.addInput(input!)
            }
            output = AVCaptureAudioDataOutput()
            if captureSession.canAddOutput(output!) {
                captureSession.addOutput(output!)
            }
        } else {
            input = nil
            output = nil
        }
    }

    func addReplaceAudioPCMBuffer(id: UUID, _ audioBuffer: AVAudioPCMBuffer) {
        lockQueue.async {
            self.addReplaceAudioPCMBufferInner(id: id, audioBuffer)
        }
    }

    func addReplaceAudioPCMBufferInner(id: UUID, _ audioBuffer: AVAudioPCMBuffer) {
        guard let replaceAudio = replaceAudios[id] else {
            return
        }
        let sampleBuffer = replaceAudio.createSampleBuffer(audioPCMBuffer: audioBuffer)
        guard let sampleBuffer, selectedReplaceAudioId != nil else {
            return
        }
        var audioLevel: Float = .infinity
        var numberOfAudioChannels = sampleBuffer.formatDescription?.audioChannelLayout?.numberOfChannels ?? 0
        prepareSampleBuffer(
            sampleBuffer: sampleBuffer,
            audioLevel: audioLevel,
            numberOfAudioChannels: numberOfAudioChannels
        )
    }

    func addReplaceAudio(cameraId: UUID) {
        lockQueue.async {
            self.addReplaceAudioInner(cameraId: cameraId)
        }
    }

    func addReplaceAudioInner(cameraId: UUID) {
        let replaceAudio = ReplaceAudio()
        replaceAudios[cameraId] = replaceAudio
    }

    func removeReplaceAudio(cameraId: UUID) {
        lockQueue.async {
            self.removeReplaceAudioInner(cameraId: cameraId)
        }
    }

    func removeReplaceAudioInner(cameraId: UUID) {
        replaceAudios.removeValue(forKey: cameraId)
    }

    func prepareSampleBuffer(sampleBuffer: CMSampleBuffer, audioLevel: Float, numberOfAudioChannels: Int) {
        // Workaround for audio drift on iPhone 15 Pro Max running iOS 17. Probably issue on more models.
        let presentationTimeStamp = syncTimeToVideo(mixer: mixer!, sampleBuffer: sampleBuffer)
        guard mixer!.useSampleBuffer(presentationTimeStamp, mediaType: AVMediaType.audio) else {
            return
        }
        mixer!.delegate?.mixer(
            audioLevel: audioLevel,
            numberOfAudioChannels: numberOfAudioChannels,
            presentationTimestamp: presentationTimeStamp.seconds
        )
        appendSampleBuffer(sampleBuffer, presentationTimeStamp, isFirstAfterAttach: false)
    }

    private func syncTimeToVideo(mixer: Mixer, sampleBuffer: CMSampleBuffer) -> CMTime {
        var presentationTimeStamp = sampleBuffer.presentationTimeStamp
        if #available(iOS 16.0, *) {
            if let audioClock = mixer.audioSession.synchronizationClock,
               let videoClock = mixer.videoSession.synchronizationClock
            {
                let audioTimescale = sampleBuffer.presentationTimeStamp.timescale
                let seconds = audioClock.convertTime(presentationTimeStamp, to: videoClock).seconds
                let value = CMTimeValue(seconds * Double(audioTimescale))
                presentationTimeStamp = CMTime(value: value, timescale: audioTimescale)
            }
        }
        return presentationTimeStamp
    }
}

extension AudioUnit: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(
        _: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard selectedReplaceAudioId == nil else {
            return
        }
        var audioLevel: Float
        if muted {
            audioLevel = .nan
        } else if let channel = connection.audioChannels.first {
            audioLevel = channel.averagePowerLevel
        } else {
            audioLevel = 0.0
        }
        var numberOfAudioChannels = connection.audioChannels.count
        prepareSampleBuffer(
            sampleBuffer: sampleBuffer,
            audioLevel: audioLevel,
            numberOfAudioChannels: numberOfAudioChannels
        )
    }
}
