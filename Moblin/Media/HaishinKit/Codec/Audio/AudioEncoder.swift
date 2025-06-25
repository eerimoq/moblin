import AVFoundation

protocol AudioCodecDelegate: AnyObject {
    func audioCodecOutputFormat(_ format: AVAudioFormat)
    func audioCodecOutputBuffer(_ buffer: AVAudioBuffer, _ presentationTimeStamp: CMTime)
}

class AudioEncoder {
    weak var delegate: (any AudioCodecDelegate)?
    private var isRunning: Atomic<Bool> = .init(false)
    private let lockQueue: DispatchQueue
    private var ringBuffer: AudioEncoderRingBuffer?
    private var audioConverter: AVAudioConverter?

    var settings = AudioEncoderSettings() {
        didSet {
            audioConverter?.setBitrate(to: settings.bitrate)
        }
    }

    var inSourceFormat: AudioStreamBasicDescription? {
        didSet {
            guard var inSourceFormat, inSourceFormat != oldValue else {
                return
            }
            ringBuffer = .init(&inSourceFormat)
            audioConverter = makeAudioConverter(&inSourceFormat)
        }
    }

    init(lockQueue: DispatchQueue) {
        self.lockQueue = lockQueue
    }

    static func makeAudioFormat(_ basicDescription: inout AudioStreamBasicDescription) -> AVAudioFormat? {
        return AVAudioFormat(
            streamDescription: &basicDescription,
            channelLayout: makeChannelLayout(basicDescription.mChannelsPerFrame)
        )
    }

    private static func makeChannelLayout(_ numberOfChannels: UInt32) -> AVAudioChannelLayout? {
        guard numberOfChannels > 2 else {
            return nil
        }
        return AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_DiscreteInOrder | numberOfChannels)
    }

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer, _ presentationTimeStamp: CMTime) {
        guard isRunning.value else {
            return
        }
        switch settings.format {
        case .aac:
            appendSampleBufferOutputAac(sampleBuffer, presentationTimeStamp)
        case .opus:
            appendSampleBufferOutputOpus(sampleBuffer, presentationTimeStamp)
        }
    }

    private func appendSampleBufferOutputAac(_ sampleBuffer: CMSampleBuffer, _ presentationTimeStamp: CMTime) {
        guard let audioConverter, let ringBuffer else {
            return
        }
        var offset = 0
        while offset < sampleBuffer.numSamples {
            offset += ringBuffer.appendSampleBuffer(sampleBuffer, presentationTimeStamp, offset)
            if let (outputBuffer, latestPresentationTimeStamp) = ringBuffer.getReadyOutputBuffer() {
                convertBuffer(audioConverter, outputBuffer, latestPresentationTimeStamp)
            }
        }
    }

    private func appendSampleBufferOutputOpus(_ sampleBuffer: CMSampleBuffer, _ presentationTimeStamp: CMTime) {
        guard let audioConverter, let ringBuffer else {
            return
        }
        var offset = 0
        while offset < sampleBuffer.numSamples {
            offset += ringBuffer.appendSampleBuffer(sampleBuffer, presentationTimeStamp, offset)
            if let (outputBuffer, latestPresentationTimeStamp) = ringBuffer.getReadyOutputBuffer() {
                convertBuffer(audioConverter, outputBuffer, latestPresentationTimeStamp)
            }
        }
    }

    private func convertBuffer(
        _ audioConverter: AVAudioConverter,
        _ inputBuffer: AVAudioBuffer,
        _ presentationTimeStamp: CMTime
    ) {
        let outputBuffer = settings.format.makeAudioBuffer(audioConverter.outputFormat)
        var error: NSError?
        audioConverter.convert(to: outputBuffer, error: &error) { _, status in
            status.pointee = .haveData
            return inputBuffer
        }
        if let error {
            logger.info("audio-encoder: Failed to convert \(error)")
        } else {
            delegate?.audioCodecOutputBuffer(outputBuffer, presentationTimeStamp)
        }
    }

    private func makeAudioConverter(_ inSourceFormat: inout AudioStreamBasicDescription) -> AVAudioConverter? {
        guard
            let inputFormat = Self.makeAudioFormat(&inSourceFormat),
            let outputFormat = settings.format.makeAudioFormat(inSourceFormat)
        else {
            return nil
        }
        logger.debug("audio-encoder: inputFormat: \(inputFormat)")
        logger.debug("audio-encoder: outputFormat: \(outputFormat)")
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            logger.info("audio-encoder: Failed to create from \(inputFormat) to \(outputFormat)")
            return nil
        }
        converter.channelMap = makeChannelMap(
            numberOfInputChannels: Int(inputFormat.channelCount),
            numberOfOutputChannels: Int(outputFormat.channelCount),
            outputToInputChannelsMap: settings.channelsMap
        )
        converter.setBitrate(to: settings.bitrate)
        delegate?.audioCodecOutputFormat(outputFormat)
        return converter
    }

    func startRunning() {
        lockQueue.async {
            guard !self.isRunning.value else {
                return
            }
            if let audioConverter = self.audioConverter {
                self.delegate?.audioCodecOutputFormat(audioConverter.outputFormat)
            }
            self.isRunning.mutate { $0 = true }
        }
    }

    func stopRunning() {
        lockQueue.async {
            self.inSourceFormat = nil
            self.audioConverter = nil
            self.ringBuffer = nil
            self.isRunning.mutate { $0 = false }
        }
    }
}

extension AVAudioConverter {
    func setBitrate(to bitrate: Int) {
        guard bitrate != bitRate else {
            return
        }
        guard let bitrates = applicableEncodeBitRates else {
            return
        }
        let minBitrate = bitrates.min(by: { $0.intValue < $1.intValue })?.intValue ?? bitrate
        let maxBitrate = bitrates.max(by: { $0.intValue < $1.intValue })?.intValue ?? bitrate
        bitRate = bitrate.clamped(to: minBitrate ... maxBitrate)
        logger.debug("audio-encoder: \(bitRate), maximum: \(maxBitrate)")
    }
}
