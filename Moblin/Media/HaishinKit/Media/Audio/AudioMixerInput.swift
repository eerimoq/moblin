import Accelerate
import AVFoundation

let audioMixerSampleRate = 48000.0
let audioMixerFadeFrames = 256
private let maximumFrames = 16384
private let ringFrames = 1 << 19
private let ringMask = Int64(ringFrames - 1)
private let risingFade = (0 ..< audioMixerFadeFrames).map {
    0.5 - 0.5 * cos(Float.pi * (Float($0) + 0.5) / Float(audioMixerFadeFrames))
}

private let fallingFade = risingFade.map { 1 - $0 }

enum AudioMixerInputKind {
    case builtin
    case buffered
}

func makeAudioMixerIndex(_ time: CMTime) -> Int64 {
    time.convertScale(Int32(audioMixerSampleRate), method: .roundHalfAwayFromZero).value
}

func makeAudioMixerSamples(count: Int) -> UnsafeMutablePointer<Float> {
    let samples = UnsafeMutablePointer<Float>.allocate(capacity: count)
    samples.initialize(repeating: 0, count: count)
    return samples
}

func fadeInAudioMixerSamples(samples: UnsafeMutablePointer<Float>, position: Int, count: Int) {
    risingFade.withUnsafeBufferPointer { fade in
        vDSP_vmul(samples, 1, fade.baseAddress! + position, 1, samples, 1, vDSP_Length(count))
    }
}

func fadeOutAudioMixerSamples(samples: UnsafeMutablePointer<Float>, position: Int, count: Int) {
    fallingFade.withUnsafeBufferPointer { fade in
        vDSP_vmul(samples, 1, fade.baseAddress! + position, 1, samples, 1, vDSP_Length(count))
    }
}

func crossfadeAudioMixerSamples(from: UnsafePointer<Float>,
                                to: UnsafePointer<Float>,
                                output: UnsafeMutablePointer<Float>)
{
    let frames = vDSP_Length(audioMixerFadeFrames)
    vDSP_vmul(from, 1, fallingFade, 1, output, 1, frames)
    vDSP_vma(to, 1, risingFade, 1, output, 1, output, 1, frames)
}

final class AudioMixerInput {
    private let kind: AudioMixerInputKind
    private(set) var numberOfChannels = 0
    private(set) var writeIndex: Int64 = 0
    private(set) var numberOfSlips = 0
    private(set) var numberOfResyncs = 0
    private(set) var latestDiscontinuityIndex: Int64 = .min
    private var ring: [UnsafeMutablePointer<Float>] = []
    private var scratch: [UnsafeMutablePointer<Float>] = []
    private let slipScratch = makeAudioMixerSamples(count: audioMixerFadeFrames)
    private var bufferList = AudioBufferList.allocate(maximumBuffers: 1)
    private var streamDescription: AudioStreamBasicDescription?
    private var isDirect = false
    private var isInt16 = false
    private var isInterleaved = false
    private var converter: AVAudioConverter?
    private var converterInput: AVAudioPCMBuffer?
    private var converterOutput: AVAudioPCMBuffer?
    private var converterBacklog = 0.0
    private var isConverterInputConsumed = true
    private var isStarted = false
    private var fadeInPosition = audioMixerFadeFrames
    private var timestampError = 0.0
    private lazy var converterInputBlock: AVAudioConverterInputBlock = { [unowned self] _, inputStatus in
        if isConverterInputConsumed {
            inputStatus.pointee = .noDataNow
            return nil
        }
        isConverterInputConsumed = true
        inputStatus.pointee = .haveData
        return converterInput
    }

    init(kind: AudioMixerInputKind) {
        self.kind = kind
    }

    deinit {
        deallocateChannels()
        slipScratch.deallocate()
        free(bufferList.unsafeMutablePointer)
    }

    var oldestIndex: Int64 {
        writeIndex - Int64(ringFrames)
    }

    func append(_ sampleBuffer: CMSampleBuffer, _ presentationTimeStamp: CMTime) {
        guard presentationTimeStamp.isNumeric, let converted = convert(sampleBuffer) else {
            return
        }
        place(makeAudioMixerIndex(presentationTimeStamp) - converted.delay, converted.count)
    }

    func read(channel: Int, at index: Int64, count: Int, into output: UnsafeMutablePointer<Float>) {
        let start = max(index, oldestIndex)
        let end = min(index + Int64(count), writeIndex)
        guard channel >= 0, channel < numberOfChannels, start < end else {
            output.update(repeating: 0, count: count)
            return
        }
        let head = Int(start - index)
        let length = Int(end - start)
        let position = Int(start & ringMask)
        let first = min(length, ringFrames - position)
        output.update(repeating: 0, count: head)
        (output + head).update(from: ring[channel] + position, count: first)
        (output + head + first).update(from: ring[channel], count: length - first)
        (output + head + length).update(repeating: 0, count: count - head - length)
    }

    private func convert(_ sampleBuffer: CMSampleBuffer) -> (count: Int, delay: Int64)? {
        guard var description = sampleBuffer.formatDescription?.audioStreamBasicDescription,
              description.mFormatID == kAudioFormatLinearPCM,
              description.mSampleRate > 0,
              description.mChannelsPerFrame > 0
        else {
            return nil
        }
        let count = sampleBuffer.numSamples
        guard count > 0,
              count <= maximumFrames,
              Double(count) * audioMixerSampleRate / description.mSampleRate <= Double(maximumFrames)
        else {
            return nil
        }
        if description != streamDescription {
            setFormat(&description)
        }
        if let converter {
            return convertWithConverter(converter, sampleBuffer, count)
        }
        guard isDirect else {
            return nil
        }
        var blockBuffer: CMBlockBuffer?
        guard CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: bufferList.unsafeMutablePointer,
            bufferListSize: AudioBufferList.sizeInBytes(maximumBuffers: isInterleaved ? 1 : numberOfChannels),
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: &blockBuffer
        ) == noErr, Int(bufferList[0].mDataByteSize) >= count * Int(description.mBytesPerFrame) else {
            return nil
        }
        withExtendedLifetime(blockBuffer) {
            convertDirect(count)
        }
        return (count, 0)
    }

    private func convertDirect(_ count: Int) {
        let stride = isInterleaved ? numberOfChannels : 1
        let frames = vDSP_Length(count)
        var scale: Float = isInt16 ? 1 / 32768 : 1
        for channel in 0 ..< numberOfChannels {
            let data = bufferList[isInterleaved ? 0 : channel].mData!
            let offset = isInterleaved ? channel : 0
            let output = scratch[channel]
            if isInt16 {
                vDSP_vflt16(data.assumingMemoryBound(to: Int16.self) + offset, stride, output, 1, frames)
                vDSP_vsmul(output, 1, &scale, output, 1, frames)
            } else {
                let input = data.assumingMemoryBound(to: Float.self) + offset
                vDSP_vsmul(input, stride, &scale, output, 1, frames)
            }
        }
    }

    private func convertWithConverter(_ converter: AVAudioConverter,
                                      _ sampleBuffer: CMSampleBuffer,
                                      _ count: Int) -> (count: Int, delay: Int64)?
    {
        guard let converterInput, let converterOutput else {
            return nil
        }
        converterInput.frameLength = AVAudioFrameCount(count)
        guard CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer,
            at: 0,
            frameCount: Int32(count),
            into: converterInput.mutableAudioBufferList
        ) == noErr else {
            return nil
        }
        converterOutput.frameLength = 0
        isConverterInputConsumed = false
        var error: NSError?
        let status = converter.convert(to: converterOutput, error: &error, withInputFrom: converterInputBlock)
        guard status != .error, let data = converterOutput.floatChannelData else {
            logger.info("audio-mixer: Conversion failed: \(error?.localizedDescription ?? "")")
            converter.reset()
            converterBacklog = 0
            return nil
        }
        let frames = Int(converterOutput.frameLength)
        for channel in 0 ..< numberOfChannels {
            scratch[channel].update(from: data[channel], count: frames)
        }
        let delay = Int64(converterBacklog.rounded())
        converterBacklog += Double(count) * audioMixerSampleRate / converter.inputFormat.sampleRate
        converterBacklog -= Double(frames)
        return frames > 0 ? (frames, delay) : nil
    }

    private func setFormat(_ description: inout AudioStreamBasicDescription) {
        streamDescription = description
        let channels = Int(description.mChannelsPerFrame)
        if channels != numberOfChannels {
            allocateChannels(channels)
        }
        let flags = description.mFormatFlags
        let bits = description.mBitsPerChannel
        let isFloat = flags & kAudioFormatFlagIsFloat != 0
        let isSignedInteger = flags & kAudioFormatFlagIsSignedInteger != 0
        let isBigEndian = flags & kAudioFormatFlagIsBigEndian != 0
        isInterleaved = flags & kAudioFormatFlagIsNonInterleaved == 0
        isInt16 = !isFloat && isSignedInteger && bits == 16
        let bytesPerFrame = (isInterleaved ? description.mChannelsPerFrame : 1) * bits / 8
        isDirect = description.mSampleRate == audioMixerSampleRate
            && !isBigEndian
            && description.mBytesPerFrame == bytesPerFrame
            && (isInt16 || (isFloat && bits == 32))
        converter = nil
        converterInput = nil
        converterOutput = nil
        converterBacklog = 0
        if !isDirect {
            makeConverter(&description, channels)
        }
        logger.info("""
        audio-mixer: Input format \(description.mSampleRate) Hz, \(channels) channels, \
        \(bits) bits, direct \(isDirect), converter \(converter != nil)
        """)
    }

    private func makeConverter(_ description: inout AudioStreamBasicDescription, _ channels: Int) {
        let layoutTag = kAudioChannelLayoutTag_DiscreteInOrder | UInt32(channels)
        guard let layout = AVAudioChannelLayout(layoutTag: layoutTag),
              let inputFormat = AVAudioFormat(streamDescription: &description, channelLayout: layout)
        else {
            return
        }
        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                         sampleRate: audioMixerSampleRate,
                                         interleaved: false,
                                         channelLayout: layout)
        converter = AVAudioConverter(from: inputFormat, to: outputFormat)
        converterInput = AVAudioPCMBuffer(pcmFormat: inputFormat,
                                          frameCapacity: AVAudioFrameCount(maximumFrames))
        converterOutput = AVAudioPCMBuffer(pcmFormat: outputFormat,
                                           frameCapacity: AVAudioFrameCount(2 * maximumFrames))
    }

    private func place(_ index: Int64, _ count: Int) {
        var count = count
        var skip = 0
        let delta = index - writeIndex
        if !isStarted || abs(delta) > 2400 {
            if isStarted {
                numberOfResyncs += 1
            }
            jump(to: index)
        } else if kind == .builtin {
            count = slip(delta, count)
        } else if delta > 96 {
            logger.debug("audio-mixer: Gap of \(delta) frames")
            jump(to: index)
        } else if delta < -96 {
            logger.debug("audio-mixer: Overlap of \(-delta) frames")
            skip = Int(-delta)
            fadeOutTail(writeIndex)
            fadeInPosition = 0
            latestDiscontinuityIndex = writeIndex
        }
        if skip < count {
            write(skip, count - skip)
        }
    }

    private func jump(to index: Int64) {
        if isStarted {
            fadeOutTail(min(index, writeIndex))
            clear(min(index, writeIndex), Int(min(abs(index - writeIndex), Int64(ringFrames))))
        }
        writeIndex = index
        isStarted = true
        fadeInPosition = 0
        timestampError = 0
        latestDiscontinuityIndex = index
    }

    private func slip(_ delta: Int64, _ count: Int) -> Int {
        timestampError += (Double(delta) - timestampError) * 0.05
        guard abs(timestampError) > 48, count > audioMixerFadeFrames else {
            return count
        }
        numberOfSlips += 1
        if timestampError > 0 {
            timestampError -= 1
            insertFrame(count)
            return count + 1
        } else {
            timestampError += 1
            dropFrame(count)
            return count - 1
        }
    }

    private func insertFrame(_ count: Int) {
        let previousPosition = Int((writeIndex - 1) & ringMask)
        let frames = audioMixerFadeFrames
        for channel in 0 ..< numberOfChannels {
            let samples = scratch[channel]
            slipScratch[0] = ring[channel][previousPosition]
            (slipScratch + 1).update(from: samples, count: frames - 1)
            (samples + frames).update(from: samples + frames - 1, count: count - frames + 1)
            crossfadeAudioMixerSamples(from: samples, to: slipScratch, output: samples)
        }
    }

    private func dropFrame(_ count: Int) {
        let frames = audioMixerFadeFrames
        for channel in 0 ..< numberOfChannels {
            let samples = scratch[channel]
            crossfadeAudioMixerSamples(from: samples, to: samples + 1, output: slipScratch)
            (samples + frames).update(from: samples + frames + 1, count: count - frames - 1)
            samples.update(from: slipScratch, count: frames)
        }
    }

    private func write(_ offset: Int, _ count: Int) {
        if fadeInPosition < audioMixerFadeFrames {
            let frames = min(count, audioMixerFadeFrames - fadeInPosition)
            for channel in 0 ..< numberOfChannels {
                fadeInAudioMixerSamples(
                    samples: scratch[channel] + offset,
                    position: fadeInPosition,
                    count: frames
                )
            }
            fadeInPosition += frames
        }
        let position = Int(writeIndex & ringMask)
        let first = min(count, ringFrames - position)
        for channel in 0 ..< numberOfChannels {
            (ring[channel] + position).update(from: scratch[channel] + offset, count: first)
            ring[channel].update(from: scratch[channel] + offset + first, count: count - first)
        }
        writeIndex += Int64(count)
    }

    private func fadeOutTail(_ end: Int64) {
        let position = Int((end - Int64(audioMixerFadeFrames)) & ringMask)
        let first = min(audioMixerFadeFrames, ringFrames - position)
        for channel in 0 ..< numberOfChannels {
            fadeOutAudioMixerSamples(samples: ring[channel] + position, position: 0, count: first)
            fadeOutAudioMixerSamples(samples: ring[channel],
                                     position: first,
                                     count: audioMixerFadeFrames - first)
        }
    }

    private func clear(_ index: Int64, _ count: Int) {
        let position = Int(index & ringMask)
        let first = min(count, ringFrames - position)
        for channel in 0 ..< numberOfChannels {
            (ring[channel] + position).update(repeating: 0, count: first)
            ring[channel].update(repeating: 0, count: count - first)
        }
    }

    private func allocateChannels(_ channels: Int) {
        deallocateChannels()
        numberOfChannels = channels
        ring = (0 ..< channels).map { _ in makeAudioMixerSamples(count: ringFrames) }
        scratch = (0 ..< channels).map { _ in makeAudioMixerSamples(count: 2 * maximumFrames + 1) }
        free(bufferList.unsafeMutablePointer)
        bufferList = AudioBufferList.allocate(maximumBuffers: channels)
        isStarted = false
    }

    private func deallocateChannels() {
        for samples in ring + scratch {
            samples.deallocate()
        }
        ring = []
        scratch = []
    }
}
