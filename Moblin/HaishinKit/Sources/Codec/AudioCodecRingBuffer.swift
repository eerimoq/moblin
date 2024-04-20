import Accelerate
import AVFoundation
import Foundation

final class AudioCodecRingBuffer {
    var isOutputBufferReady: Bool {
        numSamplesPerBuffer == index
    }

    private(set) var latestPresentationTimeStamp: CMTime = .invalid
    private var index = 0
    private var numSamplesPerBuffer: Int
    private var format: AVAudioFormat
    private(set) var outputBuffer: AVAudioPCMBuffer
    private var workingBuffer: AVAudioPCMBuffer

    init?(_ inputBasicDescription: inout AudioStreamBasicDescription) {
        numSamplesPerBuffer = 1024
        guard
            inputBasicDescription.mFormatID == kAudioFormatLinearPCM,
            let format = AudioCodec.makeAudioFormat(&inputBasicDescription),
            let outputBuffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: UInt32(numSamplesPerBuffer)
            ),
            let workingBuffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: UInt32(numSamplesPerBuffer)
            )
        else {
            return nil
        }
        outputBuffer.frameLength = UInt32(numSamplesPerBuffer)
        self.format = format
        self.outputBuffer = outputBuffer
        self.workingBuffer = workingBuffer
    }

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer, _ presentationTimeStamp: CMTime,
                            _ offset: Int) -> Int
    {
        if latestPresentationTimeStamp == .invalid {
            let offsetTimeStamp: CMTime = offset == 0 ? .zero : CMTime(
                value: CMTimeValue(offset),
                timescale: presentationTimeStamp.timescale
            )
            latestPresentationTimeStamp = CMTimeAdd(presentationTimeStamp, offsetTimeStamp)
        }
        if offset == 0 {
            if workingBuffer.frameLength < sampleBuffer.numSamples {
                if let buffer = AVAudioPCMBuffer(
                    pcmFormat: format,
                    frameCapacity: AVAudioFrameCount(sampleBuffer.numSamples)
                ) {
                    workingBuffer = buffer
                }
            }
            workingBuffer.frameLength = AVAudioFrameCount(sampleBuffer.numSamples)
            CMSampleBufferCopyPCMDataIntoAudioBufferList(
                sampleBuffer,
                at: 0,
                frameCount: Int32(sampleBuffer.numSamples),
                into: workingBuffer.mutableAudioBufferList
            )
            if kLinearPCMFormatFlagIsBigEndian ==
                ((sampleBuffer.formatDescription?.audioStreamBasicDescription?.mFormatFlags ?? 0) &
                    kLinearPCMFormatFlagIsBigEndian)
            {
                if format.isInterleaved {
                    switch format.commonFormat {
                    case .pcmFormatInt16:
                        let length = sampleBuffer.dataBuffer?.dataLength ?? 0
                        var image = vImage_Buffer(
                            data: workingBuffer.mutableAudioBufferList[0].mBuffers.mData,
                            height: 1,
                            width: vImagePixelCount(length / 2),
                            rowBytes: length
                        )
                        vImageByteSwap_Planar16U(&image, &image, vImage_Flags(kvImageNoFlags))
                    default:
                        break
                    }
                }
            }
        }
        let numSamples = min(numSamplesPerBuffer - index, Int(sampleBuffer.numSamples) - offset)
        if format.isInterleaved {
            let channelCount = Int(format.channelCount)
            switch format.commonFormat {
            case .pcmFormatInt16:
                memcpy(
                    outputBuffer.int16ChannelData?[0].advanced(by: index * channelCount),
                    workingBuffer.int16ChannelData?[0].advanced(by: offset * channelCount),
                    numSamples * 2 * channelCount
                )
            case .pcmFormatInt32:
                memcpy(
                    outputBuffer.int32ChannelData?[0].advanced(by: index * channelCount),
                    workingBuffer.int32ChannelData?[0].advanced(by: offset * channelCount),
                    numSamples * 4 * channelCount
                )
            case .pcmFormatFloat32:
                memcpy(
                    outputBuffer.floatChannelData?[0].advanced(by: index * channelCount),
                    workingBuffer.floatChannelData?[0].advanced(by: offset * channelCount),
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
                        outputBuffer.int16ChannelData?[i].advanced(by: index),
                        workingBuffer.int16ChannelData?[i].advanced(by: offset),
                        numSamples * 2
                    )
                case .pcmFormatInt32:
                    memcpy(
                        outputBuffer.int32ChannelData?[i].advanced(by: index),
                        workingBuffer.int32ChannelData?[i].advanced(by: offset),
                        numSamples * 4
                    )
                case .pcmFormatFloat32:
                    memcpy(
                        outputBuffer.floatChannelData?[i].advanced(by: index),
                        workingBuffer.floatChannelData?[i].advanced(by: offset),
                        numSamples * 4
                    )
                default:
                    break
                }
            }
        }
        index += numSamples

        return numSamples
    }

    func next() {
        latestPresentationTimeStamp = .invalid
        index = 0
    }
}
