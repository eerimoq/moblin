import AVFoundation

protocol AudioCodecDelegate: AnyObject {
    func audioCodecOutputFormat(_ format: AVAudioFormat)
    func audioCodecOutputBuffer(_ buffer: AVAudioBuffer, _ presentationTimeStamp: CMTime)
}

class AudioCodec {
    init(lockQueue: DispatchQueue) {
        self.lockQueue = lockQueue
    }

    static func makeAudioFormat(_ basicDescription: inout AudioStreamBasicDescription) -> AVAudioFormat? {
        if basicDescription.mFormatID == kAudioFormatLinearPCM,
           kLinearPCMFormatFlagIsBigEndian ==
           (basicDescription.mFormatFlags & kLinearPCMFormatFlagIsBigEndian)
        {
            // ReplayKit audioApp.
            guard basicDescription.mBitsPerChannel == 16 else {
                return nil
            }
            if let layout = makeChannelLayout(basicDescription.mChannelsPerFrame) {
                return .init(
                    commonFormat: .pcmFormatInt16,
                    sampleRate: basicDescription.mSampleRate,
                    interleaved: true,
                    channelLayout: layout
                )
            }
            return AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: basicDescription.mSampleRate,
                channels: basicDescription.mChannelsPerFrame,
                interleaved: true
            )
        }
        if let layout = makeChannelLayout(basicDescription.mChannelsPerFrame) {
            return .init(streamDescription: &basicDescription, channelLayout: layout)
        }
        return .init(streamDescription: &basicDescription)
    }

    static func makeChannelLayout(_ numberOfChannels: UInt32) -> AVAudioChannelLayout? {
        guard numberOfChannels > 2 else {
            return nil
        }
        return AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_DiscreteInOrder | numberOfChannels)
    }

    weak var delegate: (any AudioCodecDelegate)?
    private var isRunning: Atomic<Bool> = .init(false)
    var outputSettings: AudioCodecOutputSettings = .default {
        didSet {
            guard let audioConverter else {
                return
            }
            outputSettings.apply(audioConverter, oldValue: oldValue)
        }
    }

    private let lockQueue: DispatchQueue
    var inSourceFormat: AudioStreamBasicDescription? {
        didSet {
            guard var inSourceFormat, inSourceFormat != oldValue else {
                return
            }
            ringBuffer = .init(&inSourceFormat)
            audioConverter = makeAudioConverter(&inSourceFormat)
        }
    }

    private var ringBuffer: AudioCodecRingBuffer?
    private var audioConverter: AVAudioConverter?

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer, _ presentationTimeStamp: CMTime) {
        guard isRunning.value else {
            return
        }
        switch outputSettings.format {
        case .pcm:
            appendSampleBufferOutputPcm(sampleBuffer, presentationTimeStamp)
        case .aac:
            appendSampleBufferOutputAac(sampleBuffer, presentationTimeStamp)
        case .opus:
            appendSampleBufferOutputOpus(sampleBuffer, presentationTimeStamp)
        }
    }

    private func appendSampleBufferOutputPcm(_ sampleBuffer: CMSampleBuffer,
                                             _ presentationTimeStamp: CMTime)
    {
        guard let blockBuffer = sampleBuffer.dataBuffer else {
            return
        }
        var offset = 0
        var nextPresentationTimeStamp = presentationTimeStamp
        for i in 0 ..< sampleBuffer.numSamples {
            guard let buffer = makeInputBuffer() as? AVAudioCompressedBuffer else {
                continue
            }
            let sampleSize = sampleBuffer.getSampleSize(at: i)
            let byteCount = sampleSize - AdtsHeader.size
            buffer.packetDescriptions?.pointee = AudioStreamPacketDescription(
                mStartOffset: 0,
                mVariableFramesInPacket: 0,
                mDataByteSize: UInt32(byteCount)
            )
            buffer.packetCount = 1
            buffer.byteLength = UInt32(byteCount)
            blockBuffer.copyDataBytes(
                fromOffset: offset + AdtsHeader.size,
                length: byteCount,
                to: buffer.data
            )
            appendAudioBuffer(buffer, presentationTimeStamp: nextPresentationTimeStamp)
            nextPresentationTimeStamp = CMTimeAdd(
                nextPresentationTimeStamp,
                CMTime(
                    value: CMTimeValue(1024),
                    timescale: presentationTimeStamp.timescale
                )
            )
            offset += sampleSize
        }
    }

    private func appendSampleBufferOutputAac(_ sampleBuffer: CMSampleBuffer,
                                             _ presentationTimeStamp: CMTime)
    {
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

    private func appendSampleBufferOutputOpus(_ sampleBuffer: CMSampleBuffer,
                                              _ presentationTimeStamp: CMTime)
    {
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

    func appendAudioBuffer(_ audioBuffer: AVAudioBuffer, presentationTimeStamp: CMTime) {
        guard isRunning.value, let audioConverter else {
            return
        }
        convertBuffer(audioConverter, audioBuffer, presentationTimeStamp)
    }

    private func convertBuffer(
        _ audioConverter: AVAudioConverter,
        _ inputBuffer: AVAudioBuffer,
        _ presentationTimeStamp: CMTime
    ) {
        guard let outputBuffer = createOutputBuffer(audioConverter) else {
            return
        }
        var error: NSError?
        audioConverter.convert(to: outputBuffer, error: &error) { _, status in
            status.pointee = .haveData
            return inputBuffer
        }
        if let error {
            logger.info("Failed to convert \(error)")
        } else {
            delegate?.audioCodecOutputBuffer(outputBuffer, presentationTimeStamp)
        }
    }

    func makeInputBuffer() -> AVAudioBuffer? {
        guard let inputFormat = audioConverter?.inputFormat else {
            return nil
        }
        switch inSourceFormat?.mFormatID {
        case kAudioFormatLinearPCM:
            return AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: 1024)
        default:
            return AVAudioCompressedBuffer(format: inputFormat, packetCapacity: 1, maximumPacketSize: 1024)
        }
    }

    private func createOutputBuffer(_ audioConverter: AVAudioConverter) -> AVAudioBuffer? {
        return outputSettings.format.makeAudioBuffer(audioConverter.outputFormat)
    }

    private func makeAudioConverter(_ inSourceFormat: inout AudioStreamBasicDescription)
        -> AVAudioConverter?
    {
        guard
            let inputFormat = Self.makeAudioFormat(&inSourceFormat),
            let outputFormat = outputSettings.format.makeAudioFormat(inSourceFormat)
        else {
            return nil
        }
        logger.info("inputFormat: \(inputFormat)")
        logger.info("outputFormat: \(outputFormat)")
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            logger.info("Failed to create from \(inputFormat) to \(outputFormat)")
            return nil
        }
        converter.channelMap = makeChannelMap(
            numberOfInputChannels: Int(inputFormat.channelCount),
            numberOfOutputChannels: Int(outputFormat.channelCount),
            outputToInputChannelsMap: outputSettings.channelsMap
        )
        outputSettings.apply(converter, oldValue: nil)
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
