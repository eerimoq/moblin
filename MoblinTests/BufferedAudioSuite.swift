import AVFoundation
@testable import Moblin
import Testing

private func createSampleBuffer(presentationTimeStamp: Double) -> CMSampleBuffer {
    let format = AVAudioFormat(commonFormat: .pcmFormatInt16,
                               sampleRate: 48000,
                               channels: 1,
                               interleaved: false)!
    return CMSampleBuffer.createSilent(format, CMTime(seconds: presentationTimeStamp), 1024)!
}

struct BufferedAudioSuite {
    @Test
    func processSomeBuffers() async throws {
        let bufferedAudio = BufferedAudio(cameraId: .init(),
                                          name: "",
                                          latency: 0.1,
                                          processor: nil,
                                          manualOutput: true)
        let sampleBuffer1 = createSampleBuffer(presentationTimeStamp: 1.000)
        let sampleBuffer2 = createSampleBuffer(presentationTimeStamp: 1.021)
        let sampleBuffer3 = createSampleBuffer(presentationTimeStamp: 1.042)
        bufferedAudio.appendSampleBuffer(sampleBuffer1)
        bufferedAudio.appendSampleBuffer(sampleBuffer2)
        bufferedAudio.appendSampleBuffer(sampleBuffer3)
        #expect(bufferedAudio.numberOfBuffers() == 3)
        #expect(bufferedAudio.getSampleBuffer(1.000) === sampleBuffer1)
        #expect(bufferedAudio.getSampleBuffer(1.021) === sampleBuffer2)
        #expect(bufferedAudio.getSampleBuffer(1.042) === sampleBuffer3)
        #expect(bufferedAudio.numberOfBuffers() == 0)
        #expect(bufferedAudio.getSampleBuffer(1.063) === sampleBuffer3)
        #expect(bufferedAudio.numberOfBuffers() == 0)
    }

    @Test
    func oa6BadAudioTimestamps() async throws {
        let bufferedAudio = BufferedAudio(cameraId: .init(),
                                          name: "",
                                          latency: 0.1,
                                          processor: nil,
                                          manualOutput: true)
        let sampleBuffer1 = createSampleBuffer(presentationTimeStamp: 565.064)
        let sampleBuffer2 = createSampleBuffer(presentationTimeStamp: 565.097)
        let sampleBuffer3 = createSampleBuffer(presentationTimeStamp: 565.097)
        let sampleBuffer4 = createSampleBuffer(presentationTimeStamp: 565.131)
        let sampleBuffer5 = createSampleBuffer(presentationTimeStamp: 565.164)
        let sampleBuffer6 = createSampleBuffer(presentationTimeStamp: 565.164)
        let sampleBuffer7 = createSampleBuffer(presentationTimeStamp: 565.197)
        let sampleBuffer8 = createSampleBuffer(presentationTimeStamp: 565.197)
        let sampleBuffer9 = createSampleBuffer(presentationTimeStamp: 565.231)
        let sampleBuffer10 = createSampleBuffer(presentationTimeStamp: 565.231)
        bufferedAudio.appendSampleBuffer(sampleBuffer1)
        bufferedAudio.appendSampleBuffer(sampleBuffer2)
        bufferedAudio.appendSampleBuffer(sampleBuffer3)
        bufferedAudio.appendSampleBuffer(sampleBuffer4)
        bufferedAudio.appendSampleBuffer(sampleBuffer5)
        bufferedAudio.appendSampleBuffer(sampleBuffer6)
        bufferedAudio.appendSampleBuffer(sampleBuffer7)
        bufferedAudio.appendSampleBuffer(sampleBuffer8)
        bufferedAudio.appendSampleBuffer(sampleBuffer9)
        bufferedAudio.appendSampleBuffer(sampleBuffer10)
        #expect(bufferedAudio.numberOfBuffers() == 10)
        var timestamp = 565.064
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffer1)
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffer2)
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffer3)
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffer4)
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffer5)
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffer6)
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffer7)
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffer8)
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffer9)
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffer10)
    }
}
