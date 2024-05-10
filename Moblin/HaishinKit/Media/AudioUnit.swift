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
    var audioBuffers: [AVAudioPCMBuffer] = []
    var currentAudioPCMBuffer: AVAudioPCMBuffer?

    init() {
    }

    func updateSampleBuffer(_ realPresentationTimeStamp: Double) {
        var audioPCMBuffer = currentAudioPCMBuffer
        while !audioBuffers.isEmpty {
            let replaceAudioPCMBuffer = audioBuffers.first!
            // Get first frame quickly
            if currentAudioPCMBuffer == nil {
                audioPCMBuffer = replaceAudioPCMBuffer
            }
            // Just for sanity. Should depend on FPS and latency.
            if audioBuffers.count > 200 {
                // logger.info("Over 200 frames buffered. Dropping oldest frame.")
                audioPCMBuffer = replaceAudioPCMBuffer
                audioBuffers.remove(at: 0)
                continue
            }
       //         let presentationTimeStamp = replaceAudioPCMBuffer.presentationTimeStamp.seconds
       //     if firstPresentationTimeStamp.isNaN {
       //         firstPresentationTimeStamp = realPresentationTimeStamp - presentationTimeStamp
       //     }
       //     if firstPresentationTimeStamp + presentationTimeStamp + latency > realPresentationTimeStamp {
       //         break
       //     }
            audioPCMBuffer = replaceAudioPCMBuffer
            audioBuffers.remove(at: 0)
        }
        currentAudioPCMBuffer = audioPCMBuffer
    }

    func getSampleBuffer(_ realSampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
        if let currentAudioPCMBuffer {
            return makeSampleBuffer(
                realSampleBuffer: realSampleBuffer,
                replaceAudioPCMBuffer: currentAudioPCMBuffer
            )
        } else {
            return nil
        }
    }

    private func makeSampleBuffer(realSampleBuffer: CMSampleBuffer,
                                  replaceAudioPCMBuffer: AVAudioPCMBuffer) -> CMSampleBuffer?
    {
        let sampleBuffer = replaceAudioPCMBuffer.makeSampleBuffer(presentationTimeStamp: realSampleBuffer.presentationTimeStamp)
        
      //  guard let sampleBuffer = CMSampleBuffer.create(
      //      replaceSampleBuffer!.imageBuffer!,
      //      replaceSampleBuffer!.formatDescription!,
      //      realSampleBuffer.duration,
      //      realSampleBuffer.presentationTimeStamp,
      //      realSampleBuffer.decodeTimeStamp)
      //  else {
      //      return nil
      //  }
      //  sampleBuffer!.isNotSync = replaceSampleBuffer!.isNotSync
            return sampleBuffer
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
        let isOtherReplaceAudio = lockQueue.sync {
            let oldReplaceAudio = self.selectedReplaceAudioId
            self.selectedReplaceAudioId = replaceAudio
            return replaceAudio != oldReplaceAudio
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

    func addReplaceAudioPCMBuffer(id: UUID, _ audioBuffer: AVAudioPCMBuffer) {
        guard let replaceAudio = replaceAudios[id] else {
            return
        }
        replaceAudio.audioBuffers.append(audioBuffer)
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
        guard let mixer else {
            return
        }



        for replaceAudio in replaceAudios.values {
            replaceAudio.updateSampleBuffer(sampleBuffer.presentationTimeStamp.seconds)
        }
        var sampleBuffer = sampleBuffer
        if let selectedReplaceAudioId {
            sampleBuffer = (replaceAudios[selectedReplaceAudioId]?
                .getSampleBuffer(sampleBuffer))!
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
