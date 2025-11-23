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
}
