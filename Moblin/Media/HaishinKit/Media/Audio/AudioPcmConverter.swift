import AVFoundation

final class AudioPcmConverter {
    private let name: String
    private var channelsMap: [Int: Int] = [0: 0, 1: 1]
    private var converter: AVAudioConverter?
    private var inputDescription: AudioStreamBasicDescription?
    private(set) var outputFormat: AVAudioFormat?
    private(set) var isPassthrough = false
    private var isOutputFormatFixed = false

    init(name: String) {
        self.name = name
    }

    func setChannelsMap(_ channelsMap: [Int: Int]) {
        guard channelsMap != self.channelsMap else {
            return
        }
        self.channelsMap = channelsMap
        converter = nil
        inputDescription = nil
        isPassthrough = false
    }

    func setOutputFormatFixed(_ fixed: Bool) {
        guard fixed != isOutputFormatFixed else {
            return
        }
        isOutputFormatFixed = fixed
        if !fixed {
            reset()
        }
    }

    func reset() {
        converter = nil
        inputDescription = nil
        outputFormat = nil
        isPassthrough = false
    }

    func setInputFormat(_ description: AudioStreamBasicDescription?) {
        guard description != inputDescription else {
            return
        }
        converter = nil
        inputDescription = description
        isPassthrough = false
        guard var description, let inputFormat = makeAudioFormat(&description) else {
            if !isOutputFormatFixed {
                outputFormat = nil
            }
            return
        }
        if outputFormat == nil || !isOutputFormatFixed {
            outputFormat = AVAudioFormat(
                commonFormat: inputFormat.commonFormat,
                sampleRate: 48000,
                channels: min(inputFormat.channelCount, 2),
                interleaved: inputFormat.isInterleaved
            )
        }
        guard let outputFormat else {
            return
        }
        logger.debug("\(name): Input: \(inputFormat), output: \(outputFormat)")
        let channelMap = makeChannelMap(
            numberOfInputChannels: Int(inputFormat.channelCount),
            numberOfOutputChannels: Int(outputFormat.channelCount),
            outputToInputChannelsMap: channelsMap
        )
        isPassthrough = description == outputFormat.streamDescription.pointee
            && channelMap == (0 ..< channelMap.count).map { NSNumber(value: $0) }
        guard !isPassthrough else {
            return
        }
        converter = AVAudioConverter(from: inputFormat, to: outputFormat)
        converter?.channelMap = channelMap
    }

    func convert(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
        if isPassthrough {
            return sampleBuffer
        }
        return convertToPcmBuffer(sampleBuffer)?.makeSampleBuffer(sampleBuffer.presentationTimeStamp)
    }

    private func convertToPcmBuffer(_ sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let converter else {
            return nil
        }
        let ratio = converter.outputFormat.sampleRate / converter.inputFormat.sampleRate
        let frameCapacity = AVAudioFrameCount((Double(sampleBuffer.numSamples) * ratio).rounded(.up))
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: converter.outputFormat,
            frameCapacity: frameCapacity
        )
        else {
            return nil
        }
        return try? sampleBuffer.withAudioBufferList { list, _ in
            guard let inputBuffer = AVAudioPCMBuffer(
                pcmFormat: converter.inputFormat,
                bufferListNoCopy: list.unsafePointer
            ) else {
                logger.info("\(name): Failed to create input buffer")
                return nil
            }
            nonisolated(unsafe) var inputProvided = false
            var error: NSError?
            let status = converter.convert(to: outputBuffer, error: &error) { _, inputStatus in
                if inputProvided {
                    inputStatus.pointee = .noDataNow
                    return nil
                }
                inputProvided = true
                inputStatus.pointee = .haveData
                return inputBuffer
            }
            if status == .error {
                logger.info("\(name): Convert failed with \(error?.localizedDescription ?? "")")
                return nil
            }
            guard outputBuffer.frameLength > 0 else {
                return nil
            }
            return outputBuffer
        }
    }

    private func makeChannelLayout(_ numberOfChannels: UInt32) -> AVAudioChannelLayout? {
        guard numberOfChannels > 2 else {
            return nil
        }
        return AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_DiscreteInOrder | numberOfChannels)
    }

    private func makeAudioFormat(_ basicDescription: inout AudioStreamBasicDescription) -> AVAudioFormat? {
        if basicDescription.mFormatID == kAudioFormatLinearPCM,
           kLinearPCMFormatFlagIsBigEndian ==
           (basicDescription.mFormatFlags & kLinearPCMFormatFlagIsBigEndian)
        {
            // ReplayKit audioApp.
            guard basicDescription.mBitsPerChannel == 16 else {
                return nil
            }
            if let layout = makeChannelLayout(basicDescription.mChannelsPerFrame) {
                return AVAudioFormat(
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
            return AVAudioFormat(streamDescription: &basicDescription, channelLayout: layout)
        }
        return AVAudioFormat(streamDescription: &basicDescription)
    }
}
