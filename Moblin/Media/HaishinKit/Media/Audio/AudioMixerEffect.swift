import AudioToolbox
import CoreAudio

private func renderAudioMixerEffectInput(
    _ refCon: UnsafeMutableRawPointer,
    _: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
    _: UnsafePointer<AudioTimeStamp>,
    _: UInt32,
    _ frameCount: UInt32,
    _ data: UnsafeMutablePointer<AudioBufferList>?
) -> OSStatus {
    guard let data else {
        return kAudio_ParamError
    }
    let effect = Unmanaged<AudioMixerEffect>.fromOpaque(refCon).takeUnretainedValue()
    effect.provideInput(UnsafeMutableAudioBufferListPointer(data), frameCount)
    return noErr
}

final class AudioMixerEffect {
    private(set) var latency: Int64 = 0
    let audioUnit: AudioComponentInstance
    private let output: UnsafeMutableAudioBufferListPointer
    private let outputLeft: UnsafeMutablePointer<Float>
    private let outputRight: UnsafeMutablePointer<Float>
    private var timeStamp = AudioTimeStamp()
    private var renderStatus = noErr
    private var left: UnsafeMutablePointer<Float>?
    private var right: UnsafeMutablePointer<Float>?

    init?(subType: OSType) {
        var description = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: subType,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        var audioUnit: AudioComponentInstance?
        guard let component = AudioComponentFindNext(nil, &description),
              AudioComponentInstanceNew(component, &audioUnit) == noErr,
              let audioUnit
        else {
            logger.info("audio-mixer: Effect \(subType) not found")
            return nil
        }
        self.audioUnit = audioUnit
        output = AudioBufferList.allocate(maximumBuffers: 2)
        outputLeft = makeAudioMixerSamples(count: audioMixerFramesPerBlock)
        outputRight = makeAudioMixerSamples(count: audioMixerFramesPerBlock)
        timeStamp.mFlags = .sampleTimeValid
        guard initialize() else {
            logger.info("audio-mixer: Failed to initialize effect \(subType)")
            return nil
        }
    }

    deinit {
        AudioUnitUninitialize(audioUnit)
        AudioComponentInstanceDispose(audioUnit)
        free(output.unsafeMutablePointer)
        outputLeft.deallocate()
        outputRight.deallocate()
    }

    func reset() {
        AudioUnitReset(audioUnit, kAudioUnitScope_Global, 0)
    }

    func process(_ left: UnsafeMutablePointer<Float>, _ right: UnsafeMutablePointer<Float>) {
        self.left = left
        self.right = right
        let byteSize = UInt32(audioMixerFramesPerBlock * MemoryLayout<Float>.size)
        output[0] = AudioBuffer(mNumberChannels: 1, mDataByteSize: byteSize, mData: outputLeft)
        output[1] = AudioBuffer(mNumberChannels: 1, mDataByteSize: byteSize, mData: outputRight)
        var flags = AudioUnitRenderActionFlags()
        let status = AudioUnitRender(
            audioUnit,
            &flags,
            &timeStamp,
            0,
            UInt32(audioMixerFramesPerBlock),
            output.unsafeMutablePointer
        )
        timeStamp.mSampleTime += Float64(audioMixerFramesPerBlock)
        if status != renderStatus {
            logger.info("audio-mixer: Effect render status \(status)")
            renderStatus = status
        }
        guard status == noErr else {
            left.update(repeating: 0, count: audioMixerFramesPerBlock)
            right.update(repeating: 0, count: audioMixerFramesPerBlock)
            reset()
            return
        }
        copyOutput(0, left)
        copyOutput(1, right)
    }

    fileprivate func provideInput(_ data: UnsafeMutableAudioBufferListPointer, _ frameCount: UInt32) {
        let byteSize = frameCount * UInt32(MemoryLayout<Float>.size)
        for channel in 0 ..< data.count {
            data[channel].mData = UnsafeMutableRawPointer(channel == 0 ? left : right)
            data[channel].mDataByteSize = byteSize
        }
    }

    private func copyOutput(_ channel: Int, _ samples: UnsafeMutablePointer<Float>) {
        if let data = output[channel].mData {
            samples.update(from: data.assumingMemoryBound(to: Float.self), count: audioMixerFramesPerBlock)
        }
    }

    private func initialize() -> Bool {
        var format = AudioStreamBasicDescription(
            mSampleRate: audioMixerSampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 2,
            mBitsPerChannel: 32,
            mReserved: 0
        )
        let formatSize = MemoryLayout<AudioStreamBasicDescription>.size
        var maximumFrames = UInt32(audioMixerFramesPerBlock)
        var callback = AURenderCallbackStruct(
            inputProc: renderAudioMixerEffectInput,
            inputProcRefCon: Unmanaged.passUnretained(self).toOpaque()
        )
        var latency: Float64 = 0
        var latencySize = UInt32(MemoryLayout<Float64>.size)
        guard setProperty(kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, &format, formatSize),
              setProperty(kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, &format, formatSize),
              setProperty(kAudioUnitProperty_MaximumFramesPerSlice,
                          kAudioUnitScope_Global,
                          &maximumFrames,
                          MemoryLayout<UInt32>.size),
              setProperty(kAudioUnitProperty_SetRenderCallback,
                          kAudioUnitScope_Input,
                          &callback,
                          MemoryLayout<AURenderCallbackStruct>.size),
              AudioUnitInitialize(audioUnit) == noErr,
              AudioUnitGetProperty(audioUnit,
                                   kAudioUnitProperty_Latency,
                                   kAudioUnitScope_Global,
                                   0,
                                   &latency,
                                   &latencySize) == noErr
        else {
            return false
        }
        self.latency = Int64((latency * audioMixerSampleRate).rounded())
        return true
    }

    private func setProperty(_ property: AudioUnitPropertyID,
                             _ scope: AudioUnitScope,
                             _ value: UnsafeRawPointer,
                             _ size: Int) -> Bool
    {
        AudioUnitSetProperty(audioUnit, property, scope, 0, value, UInt32(size)) == noErr
    }
}

func makeAudioMixerLimiter() -> AudioMixerEffect? {
    AudioMixerEffect(subType: kAudioUnitSubType_PeakLimiter)
}
