import AVFoundation

protocol AudioEncoderDelegate: AnyObject {
    func audioEncoderOutputFormat(_ format: AVAudioFormat)
    func audioEncoderOutputBuffer(_ buffer: AVAudioCompressedBuffer, _ presentationTimeStamp: CMTime)
}

class AudioEncoder {
    weak var delegate: (any AudioEncoderDelegate)?
    private var isRunning = false
    private let lockQueue: DispatchQueue
    private var ringBuffer: AudioEncoderRingBuffer?
    private var audioConverter: AVAudioConverter?
    private var settings = AudioEncoderSettings()
    private var bitrate: Atomic<Int> = .init(128_000)
    private var sampleRate: Atomic<Double?> = .init(nil)
    private var inSourceFormat: AudioStreamBasicDescription?

    init(lockQueue: DispatchQueue) {
        self.lockQueue = lockQueue
    }

    func startRunning() {
        lockQueue.async {
            self.startRunningInternal()
        }
    }

    func stopRunning() {
        lockQueue.async {
            self.stopRunningInternal()
        }
    }

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer, _ presentationTimeStamp: CMTime) {
        guard isRunning, let audioConverter, let ringBuffer else {
            return
        }
        try? sampleBuffer.withAudioBufferList { audioBufferList, _ in
            ringBuffer.setWorkingSampleBuffer(audioBufferList, presentationTimeStamp)
            while let (outputBuffer, presentationTimeStamp) = ringBuffer.createOutputBuffer() {
                convertBuffer(audioConverter, outputBuffer, presentationTimeStamp)
            }
        }
    }

    func setSettings(settings: AudioEncoderSettings) {
        lockQueue.async {
            self.settings = settings
            self.audioConverter?.setBitrate(to: settings.bitrate)
            self.bitrate.mutate { $0 = settings.bitrate }
        }
    }

    func setInputSourceFormat(_ newInSourceFormat: AudioStreamBasicDescription?) {
        guard var newInSourceFormat, newInSourceFormat != inSourceFormat else {
            return
        }
        ringBuffer = .init(&newInSourceFormat, numSamplesPerBuffer: samplesPerBuffer())
        audioConverter = makeAudioConverter(&newInSourceFormat)
        sampleRate.mutate { $0 = newInSourceFormat.mSampleRate }
    }

    func getBitrate() -> Int {
        return bitrate.value
    }

    func getSampleRate() -> Double? {
        return sampleRate.value
    }

    static func makeAudioFormat(_ basicDescription: inout AudioStreamBasicDescription) -> AVAudioFormat? {
        return AVAudioFormat(
            streamDescription: &basicDescription,
            channelLayout: makeChannelLayout(basicDescription.mChannelsPerFrame)
        )
    }

    private func samplesPerBuffer() -> Int {
        switch settings.format {
        case .aac:
            return 1024
        case .opus:
            return 960
        }
    }

    private func startRunningInternal() {
        if let audioConverter {
            delegate?.audioEncoderOutputFormat(audioConverter.outputFormat)
        }
        isRunning = true
    }

    private func stopRunningInternal() {
        inSourceFormat = nil
        audioConverter = nil
        ringBuffer = nil
        isRunning = false
    }

    private static func makeChannelLayout(_ numberOfChannels: UInt32) -> AVAudioChannelLayout? {
        guard numberOfChannels > 2 else {
            return nil
        }
        return AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_DiscreteInOrder | numberOfChannels)
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
            delegate?.audioEncoderOutputBuffer(outputBuffer, presentationTimeStamp)
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
        delegate?.audioEncoderOutputFormat(outputFormat)
        return converter
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
