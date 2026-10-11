import AVFoundation
import Collections

private let prebufferSeconds = 0.05
private let maximumFillSeconds = 0.25

private class AudioMixerSource {
    private let name: String
    private var converter: AVAudioConverter?
    private var channels: [Deque<Float>] = []
    private var isBuffering = true

    init(name: String) {
        self.name = name
    }

    func reset(numberOfChannels: Int) {
        converter = nil
        channels = Array(repeating: [], count: numberOfChannels)
        isBuffering = true
    }

    func append(_ sampleBuffer: CMSampleBuffer, outputFormat: AVAudioFormat) {
        guard let inputBuffer = makePcmBuffer(sampleBuffer),
              let convertedBuffer = convert(inputBuffer, outputFormat),
              let data = convertedBuffer.floatChannelData
        else {
            return
        }
        let numberOfFrames = Int(convertedBuffer.frameLength)
        let numberOfInputChannels = Int(convertedBuffer.format.channelCount)
        for channel in channels.indices {
            if numberOfInputChannels == 2, channels.count == 1 {
                let left = UnsafeBufferPointer(start: data[0], count: numberOfFrames)
                let right = UnsafeBufferPointer(start: data[1], count: numberOfFrames)
                channels[channel].append(contentsOf: zip(left, right).map { ($0 + $1) / 2 })
            } else {
                let inputChannel = min(channel, numberOfInputChannels - 1)
                channels[channel].append(contentsOf: UnsafeBufferPointer(start: data[inputChannel],
                                                                         count: numberOfFrames))
            }
        }
        let maximumFill = Int(maximumFillSeconds * outputFormat.sampleRate)
        if let fill = channels.first?.count, fill > maximumFill {
            let numberOfFramesToDrop = fill - Int(prebufferSeconds * outputFormat.sampleRate)
            logger.info("audio-mixer: \(name): Dropping \(numberOfFramesToDrop) frames.")
            for channel in channels.indices {
                channels[channel].removeFirst(numberOfFramesToDrop)
            }
        }
    }

    func add(to buffer: AVAudioPCMBuffer) {
        guard let fill = channels.first?.count else {
            return
        }
        if isBuffering {
            guard fill >= Int(prebufferSeconds * buffer.format.sampleRate) else {
                return
            }
            isBuffering = false
        }
        let numberOfFrames = min(Int(buffer.frameLength), fill)
        if numberOfFrames < Int(buffer.frameLength) {
            isBuffering = true
        }
        let stride = buffer.stride
        let interleaved = buffer.format.isInterleaved
        for (channel, samples) in channels.enumerated() {
            if let data = buffer.floatChannelData {
                let output = interleaved ? data[0] + channel : data[channel]
                for frame in 0 ..< numberOfFrames {
                    output[frame * stride] = max(-1, min(1, output[frame * stride] + samples[frame]))
                }
            } else if let data = buffer.int16ChannelData {
                let output = interleaved ? data[0] + channel : data[channel]
                for frame in 0 ..< numberOfFrames {
                    let sample = Int(max(-1, min(1, samples[frame])) * 32767)
                    output[frame * stride] = Int16(clamping: Int(output[frame * stride]) + sample)
                }
            }
        }
        for channel in channels.indices {
            channels[channel].removeFirst(numberOfFrames)
        }
    }

    private func convert(_ inputBuffer: AVAudioPCMBuffer,
                         _ outputFormat: AVAudioFormat) -> AVAudioPCMBuffer?
    {
        guard let converterOutputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: outputFormat.sampleRate,
            channels: inputBuffer.format.channelCount,
            interleaved: false
        ) else {
            return nil
        }
        if converter?.inputFormat != inputBuffer.format || converter?.outputFormat != converterOutputFormat {
            converter = AVAudioConverter(from: inputBuffer.format, to: converterOutputFormat)
        }
        guard let converter else {
            return nil
        }
        let capacity = AVAudioFrameCount(
            Double(inputBuffer.frameLength) * converterOutputFormat.sampleRate / inputBuffer.format.sampleRate
        ) + 64
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: converterOutputFormat, frameCapacity: capacity)
        else {
            return nil
        }
        var isInputConsumed = false
        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { _, inputStatus in
            if isInputConsumed {
                inputStatus.pointee = .noDataNow
                return nil
            }
            isInputConsumed = true
            inputStatus.pointee = .haveData
            return inputBuffer
        }
        guard status != .error else {
            logger.info("audio-mixer: \(name): Conversion failed: \(error?.localizedDescription ?? "")")
            return nil
        }
        return outputBuffer
    }
}

private func makePcmBuffer(_ sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
    guard let formatDescription = sampleBuffer.formatDescription else {
        return nil
    }
    let format = AVAudioFormat(cmAudioFormatDescription: formatDescription)
    let numberOfFrames = sampleBuffer.numSamples
    guard numberOfFrames > 0,
          let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(numberOfFrames))
    else {
        return nil
    }
    buffer.frameLength = AVAudioFrameCount(numberOfFrames)
    let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
        sampleBuffer,
        at: 0,
        frameCount: Int32(numberOfFrames),
        into: buffer.mutableAudioBufferList
    )
    guard status == noErr else {
        return nil
    }
    return buffer
}

class AudioMixer {
    private var sources: [UUID: AudioMixerSource] = [:]
    private var outputFormat: AVAudioFormat?

    func setSources(_ sourceIds: [UUID: String]) {
        sources = sources.filter { sourceIds[$0.key] != nil }
        for (sourceId, name) in sourceIds where sources[sourceId] == nil {
            let source = AudioMixerSource(name: name)
            source.reset(numberOfChannels: Int(outputFormat?.channelCount ?? 0))
            sources[sourceId] = source
        }
    }

    func append(sourceId: UUID, _ sampleBuffer: CMSampleBuffer) {
        guard let outputFormat else {
            return
        }
        sources[sourceId]?.append(sampleBuffer, outputFormat: outputFormat)
    }

    func mix(_ sampleBuffer: CMSampleBuffer, _ presentationTimeStamp: CMTime) -> CMSampleBuffer {
        guard !sources.isEmpty, let buffer = makePcmBuffer(sampleBuffer) else {
            return sampleBuffer
        }
        guard [.pcmFormatFloat32, .pcmFormatInt16].contains(buffer.format.commonFormat) else {
            return sampleBuffer
        }
        updateOutputFormat(format: buffer.format)
        for source in sources.values {
            source.add(to: buffer)
        }
        return buffer.makeSampleBuffer(presentationTimeStamp) ?? sampleBuffer
    }

    private func updateOutputFormat(format: AVAudioFormat) {
        if let outputFormat,
           outputFormat.sampleRate == format.sampleRate,
           outputFormat.channelCount == format.channelCount
        {
            return
        }
        outputFormat = format
        for source in sources.values {
            source.reset(numberOfChannels: Int(format.channelCount))
        }
    }
}
