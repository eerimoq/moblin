import AVFoundation

final class AudioEncoderRingBuffer {
    private var latestPresentationTimeStamp: CMTime = .invalid
    private var workingIndex = 0
    private var outputIndex = 0
    private let numSamplesPerBuffer: Int
    private var format: AVAudioFormat
    private var outputBuffer: AVAudioPCMBuffer
    private var workingBuffer: AVAudioPCMBuffer
    private var workingBufferPresentationTimeStamp: CMTime = .zero

    init?(_ inputBasicDescription: inout AudioStreamBasicDescription, numSamplesPerBuffer: Int) {
        self.numSamplesPerBuffer = numSamplesPerBuffer
        guard
            inputBasicDescription.mFormatID == kAudioFormatLinearPCM,
            let format = AudioEncoder.makeAudioFormat(&inputBasicDescription),
            let outputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: UInt32(numSamplesPerBuffer)),
            let workingBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: UInt32(numSamplesPerBuffer))
        else {
            return nil
        }
        outputBuffer.frameLength = UInt32(numSamplesPerBuffer)
        self.format = format
        self.outputBuffer = outputBuffer
        self.workingBuffer = workingBuffer
    }

    func setWorkingSampleBuffer(
        _ audioBufferList: UnsafeMutableAudioBufferListPointer,
        _ presentationTimeStamp: CMTime
    ) {
        workingBufferPresentationTimeStamp = presentationTimeStamp
        workingIndex = 0
        if let buffer = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: audioBufferList.unsafePointer) {
            workingBuffer = buffer
        }
    }

    func createOutputBuffer() -> (AVAudioPCMBuffer, CMTime)? {
        if latestPresentationTimeStamp == .invalid {
            let offsetTimeStamp = CMTime(
                value: CMTimeValue(workingIndex),
                timescale: workingBufferPresentationTimeStamp.timescale
            )
            latestPresentationTimeStamp = workingBufferPresentationTimeStamp + offsetTimeStamp
        }
        let numSamples = min(numSamplesPerBuffer - outputIndex, Int(workingBuffer.frameLength) - workingIndex)
        if format.isInterleaved {
            let channelCount = Int(format.channelCount)
            switch format.commonFormat {
            case .pcmFormatInt16:
                memcpy(
                    outputBuffer.int16ChannelData?[0].advanced(by: outputIndex * channelCount),
                    workingBuffer.int16ChannelData?[0].advanced(by: workingIndex * channelCount),
                    numSamples * 2 * channelCount
                )
            case .pcmFormatInt32:
                memcpy(
                    outputBuffer.int32ChannelData?[0].advanced(by: outputIndex * channelCount),
                    workingBuffer.int32ChannelData?[0].advanced(by: workingIndex * channelCount),
                    numSamples * 4 * channelCount
                )
            case .pcmFormatFloat32:
                memcpy(
                    outputBuffer.floatChannelData?[0].advanced(by: outputIndex * channelCount),
                    workingBuffer.floatChannelData?[0].advanced(by: workingIndex * channelCount),
                    numSamples * 4 * channelCount
                )
            default:
                break
            }
        } else {
            for i in 0 ..< Int(format.channelCount) {
                switch format.commonFormat {
                case .pcmFormatInt16:
                    memcpy(
                        outputBuffer.int16ChannelData?[i].advanced(by: outputIndex),
                        workingBuffer.int16ChannelData?[i].advanced(by: workingIndex),
                        numSamples * 2
                    )
                case .pcmFormatInt32:
                    memcpy(
                        outputBuffer.int32ChannelData?[i].advanced(by: outputIndex),
                        workingBuffer.int32ChannelData?[i].advanced(by: workingIndex),
                        numSamples * 4
                    )
                case .pcmFormatFloat32:
                    memcpy(
                        outputBuffer.floatChannelData?[i].advanced(by: outputIndex),
                        workingBuffer.floatChannelData?[i].advanced(by: workingIndex),
                        numSamples * 4
                    )
                default:
                    break
                }
            }
        }
        workingIndex += numSamples
        outputIndex += numSamples
        guard numSamplesPerBuffer == outputIndex else {
            return nil
        }
        defer {
            latestPresentationTimeStamp = .invalid
            outputIndex = 0
        }
        return (outputBuffer, latestPresentationTimeStamp)
    }
}
