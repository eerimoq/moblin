import AVFoundation
@testable import Moblin

let maximumSineStep: Float = 0.5 * 2 * .pi * 1000 / 48000

func createFormat(_ commonFormat: AVAudioCommonFormat,
                  _ numberOfChannels: Int,
                  _ interleaved: Bool,
                  sampleRate: Double = 48000) -> AVAudioFormat
{
    let layoutTag = kAudioChannelLayoutTag_DiscreteInOrder | UInt32(numberOfChannels)
    return AVAudioFormat(commonFormat: commonFormat,
                         sampleRate: sampleRate,
                         interleaved: interleaved,
                         channelLayout: AVAudioChannelLayout(layoutTag: layoutTag)!)
}

func createNoise(_ channel: Int, _ frame: Int) -> Float {
    guard channel >= 0 else {
        return 0
    }
    return Float(((frame + 1) * 7919 + channel * 3331) % 52001 - 26000) / 32768
}

func createNoise(_ channel: Int, _ frames: Range<Int>) -> [Float] {
    frames.map { createNoise(channel, $0) }
}

func createSine(_: Int, _ frame: Int) -> Float {
    Float(0.5 * sin(2 * Double.pi * 1000 * Double(frame) / 48000))
}

func createSine(_ frames: Range<Int>) -> [Float] {
    frames.map { createSine(0, $0) }
}

func createRisingFade() -> [Float] {
    (0 ..< 256).map { 0.5 - 0.5 * cos(Float.pi * (Float($0) + 0.5) / 256) }
}

func createFallingFade() -> [Float] {
    createRisingFade().map { 1 - $0 }
}

func createSampleBuffer(_ format: AVAudioFormat,
                        _ firstFrame: Int,
                        _ presentationTimeStamp: CMTime,
                        frameLength: Int = 1024,
                        _ value: (Int, Int) -> Float = createNoise) -> CMSampleBuffer
{
    let numberOfChannels = Int(format.channelCount)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameLength))!
    buffer.frameLength = AVAudioFrameCount(frameLength)
    for channel in 0 ..< numberOfChannels {
        let plane = format.isInterleaved ? 0 : channel
        for frame in 0 ..< frameLength {
            let sample = value(channel, firstFrame + frame)
            let position = format.isInterleaved ? frame * numberOfChannels + channel : frame
            if format.commonFormat == .pcmFormatInt16 {
                buffer.int16ChannelData![plane][position] = Int16(sample * 32768)
            } else {
                buffer.floatChannelData![plane][position] = sample
            }
        }
    }
    return buffer.makeSampleBuffer(presentationTimeStamp)!
}

func calcMaximumStep(_ samples: [Float]) -> Float {
    zip(samples, samples.dropFirst()).map { abs($1 - $0) }.max() ?? 0
}
