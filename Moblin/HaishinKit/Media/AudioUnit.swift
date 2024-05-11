import AVFoundation

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
    var sampleBuffers: [CMSampleBuffer] = []
    var firstPresentationTimeStamp: Double = .nan
    var nextPresentationTimeStamp: CMTime = CMTime.zero
    var currentSampleBuffer: CMSampleBuffer?

    func AddAudioPCMBuffer(audioPCMBuffer: AVAudioPCMBuffer) -> CMSampleBuffer? {
        if nextPresentationTimeStamp == CMTime.zero {
            nextPresentationTimeStamp = CMClockGetTime(CMClockGetHostTimeClock())
        }
        guard let sampleBuffer = audioPCMBuffer.makeSampleBuffer(presentationTimeStamp: nextPresentationTimeStamp) else {
            return nil
        }
       // sampleBuffers.append(sampleBuffer)
        nextPresentationTimeStamp = CMTimeAdd(
                        nextPresentationTimeStamp,
                        CMTime(
                            value: CMTimeValue(Double(audioPCMBuffer.frameLength)),
                            timescale: CMTimeScale(audioPCMBuffer.format.sampleRate)
                        )
        )
        return sampleBuffer
    }

    func updateSampleBuffer(_ realPresentationTimeStamp: Double) {
        var sampleBuffer = currentSampleBuffer
        while !sampleBuffers.isEmpty {
            let replaceSampleBuffer = sampleBuffers.first!
            // Get first frame quickly
            if currentSampleBuffer == nil {
                sampleBuffer = replaceSampleBuffer
            }
            // Just for sanity. Should depend on FPS and latency.
            if sampleBuffers.count > 200 {
                // logger.info("Over 200 frames buffered. Dropping oldest frame.")
                sampleBuffer = replaceSampleBuffer
                sampleBuffers.remove(at: 0)
                continue
            }
            let presentationTimeStamp = replaceSampleBuffer.presentationTimeStamp.seconds
            if firstPresentationTimeStamp.isNaN {
                firstPresentationTimeStamp = realPresentationTimeStamp - presentationTimeStamp
            }
            if firstPresentationTimeStamp + presentationTimeStamp > realPresentationTimeStamp {
                break
            }
            sampleBuffer = replaceSampleBuffer
            sampleBuffers.remove(at: 0)
        }
        currentSampleBuffer = sampleBuffer
    }

    func getSampleBuffer(_ realSampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
        return currentSampleBuffer
    }
}

final class AudioUnit: NSObject {
    lazy var codec: AudioCodec = .init(lockQueue: lockQueue)
    private(set) var device: AVCaptureDevice?
    private var input: AVCaptureInput?
    private var output: AVCaptureAudioDataOutput?
    let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.AudioIOUnit.lock")
    var muted = false
    weak var mixer: Mixer?

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

    private var selectedReplaceAudioId: UUID?
    private var replaceAudios: [UUID: ReplaceAudio] = [:]
    private var connection123: AVCaptureConnection?

    func addReplaceAudioPCMBuffer(id: UUID, _ audioBuffer: AVAudioPCMBuffer) {
        guard let mixer else {
            return
        }
        guard let replaceAudio = replaceAudios[id] else {
            return
        }
        
        let sampleBuffer = replaceAudio.AddAudioPCMBuffer(audioPCMBuffer: audioBuffer)

        guard let sampleBuffer else {
            return
        }

        guard let selectedReplaceAudioId else {
            return
        }
        
        let presentationTimeStamp = syncTimeToVideo(mixer: mixer, sampleBuffer: sampleBuffer)
        guard mixer.useSampleBuffer(presentationTimeStamp, mediaType: AVMediaType.audio) else {
            return
        }
        var audioLevel: Float
        if muted {
            audioLevel = .nan
        } else if let channel = connection123!.audioChannels.first {
            audioLevel = channel.averagePowerLevel
        } else {
            audioLevel = 0.0
        }
        mixer.delegate?.mixer(
            audioLevel: audioLevel,
            numberOfAudioChannels: connection123!.audioChannels.count,
            presentationTimestamp: presentationTimeStamp.seconds
        )
        appendSampleBuffer(sampleBuffer, presentationTimeStamp, isFirstAfterAttach: false)
    }

    func addReplaceAudio(cameraId: UUID) {
        let replaceAudio = ReplaceAudio()
        replaceAudios[cameraId] = replaceAudio
    }

    func removeReplaceAudio(cameraId: UUID) {
        replaceAudios.removeValue(forKey: cameraId)
    }
}

extension AudioUnit: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(
        _: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        connection123 = connection

        guard let mixer else {
            return
        }
        
        if let selectedReplaceAudioId {
            return
        }

        // Workaround for audio drift on iPhone 15 Pro Max running iOS 17. Probably issue on more models.
        let presentationTimeStamp = syncTimeToVideo(mixer: mixer, sampleBuffer: sampleBuffer)
        guard mixer.useSampleBuffer(presentationTimeStamp, mediaType: AVMediaType.audio) else {
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
        mixer.delegate?.mixer(
            audioLevel: audioLevel,
            numberOfAudioChannels: connection.audioChannels.count,
            presentationTimestamp: presentationTimeStamp.seconds
        )
        appendSampleBuffer(sampleBuffer, presentationTimeStamp, isFirstAfterAttach: false)
    }
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
