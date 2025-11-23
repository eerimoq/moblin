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
    func processNormal() async throws {
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
    func processGaps() async throws {
        let bufferedAudio = BufferedAudio(cameraId: .init(),
                                          name: "",
                                          latency: 0.1,
                                          processor: nil,
                                          manualOutput: true)
        let sampleBuffer1 = createSampleBuffer(presentationTimeStamp: 1.000)
        let sampleBuffer2 = createSampleBuffer(presentationTimeStamp: 1.021)
        let sampleBuffer3 = createSampleBuffer(presentationTimeStamp: 1.210)
        let sampleBuffer4 = createSampleBuffer(presentationTimeStamp: 1.231)
        let sampleBuffer5 = createSampleBuffer(presentationTimeStamp: 1.252)
        let sampleBuffer6 = createSampleBuffer(presentationTimeStamp: 1.273)
        let sampleBuffer7 = createSampleBuffer(presentationTimeStamp: 1.294)
        bufferedAudio.appendSampleBuffer(sampleBuffer1)
        bufferedAudio.appendSampleBuffer(sampleBuffer2)
        bufferedAudio.appendSampleBuffer(sampleBuffer3)
        bufferedAudio.appendSampleBuffer(sampleBuffer4)
        bufferedAudio.appendSampleBuffer(sampleBuffer5)
        bufferedAudio.appendSampleBuffer(sampleBuffer6)
        bufferedAudio.appendSampleBuffer(sampleBuffer7)
        #expect(bufferedAudio.getSampleBuffer(1.000) === sampleBuffer1)
        #expect(bufferedAudio.getSampleBuffer(1.021) === sampleBuffer2)
        #expect(bufferedAudio.getSampleBuffer(1.042) === sampleBuffer3)
        #expect(bufferedAudio.getSampleBuffer(1.063) === sampleBuffer3)
        #expect(bufferedAudio.getSampleBuffer(1.084) === sampleBuffer3)
        #expect(bufferedAudio.getSampleBuffer(1.105) === sampleBuffer3)
        #expect(bufferedAudio.getSampleBuffer(1.126) === sampleBuffer3)
        #expect(bufferedAudio.getSampleBuffer(1.147) === sampleBuffer3)
        #expect(bufferedAudio.getSampleBuffer(1.168) === sampleBuffer3)
        #expect(bufferedAudio.getSampleBuffer(1.189) === sampleBuffer3)
        #expect(bufferedAudio.getSampleBuffer(1.210) === sampleBuffer3)
        #expect(bufferedAudio.getSampleBuffer(1.231) === sampleBuffer4)
        #expect(bufferedAudio.getSampleBuffer(1.252) === sampleBuffer5)
        #expect(bufferedAudio.getSampleBuffer(1.273) === sampleBuffer6)
        #expect(bufferedAudio.getSampleBuffer(1.294) === sampleBuffer7)
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
        let sampleBuffer11 = createSampleBuffer(presentationTimeStamp: 565.264)
        let sampleBuffer12 = createSampleBuffer(presentationTimeStamp: 565.298)
        let sampleBuffer13 = createSampleBuffer(presentationTimeStamp: 565.331)
        let sampleBuffer14 = createSampleBuffer(presentationTimeStamp: 565.331)
        let sampleBuffer15 = createSampleBuffer(presentationTimeStamp: 565.364)
        let sampleBuffer16 = createSampleBuffer(presentationTimeStamp: 565.398)
        let sampleBuffer17 = createSampleBuffer(presentationTimeStamp: 565.398)
        let sampleBuffer18 = createSampleBuffer(presentationTimeStamp: 565.431)
        let sampleBuffer19 = createSampleBuffer(presentationTimeStamp: 565.464)
        let sampleBuffer20 = createSampleBuffer(presentationTimeStamp: 565.464)
        let sampleBuffer21 = createSampleBuffer(presentationTimeStamp: 565.498)
        let sampleBuffer22 = createSampleBuffer(presentationTimeStamp: 565.531)
        let sampleBuffer23 = createSampleBuffer(presentationTimeStamp: 565.531)
        let sampleBuffer24 = createSampleBuffer(presentationTimeStamp: 565.531)
        let sampleBuffer25 = createSampleBuffer(presentationTimeStamp: 565.565)
        let sampleBuffer26 = createSampleBuffer(presentationTimeStamp: 565.598)
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
        bufferedAudio.appendSampleBuffer(sampleBuffer11)
        bufferedAudio.appendSampleBuffer(sampleBuffer12)
        bufferedAudio.appendSampleBuffer(sampleBuffer13)
        bufferedAudio.appendSampleBuffer(sampleBuffer14)
        bufferedAudio.appendSampleBuffer(sampleBuffer15)
        bufferedAudio.appendSampleBuffer(sampleBuffer16)
        bufferedAudio.appendSampleBuffer(sampleBuffer17)
        bufferedAudio.appendSampleBuffer(sampleBuffer18)
        bufferedAudio.appendSampleBuffer(sampleBuffer19)
        bufferedAudio.appendSampleBuffer(sampleBuffer20)
        bufferedAudio.appendSampleBuffer(sampleBuffer21)
        bufferedAudio.appendSampleBuffer(sampleBuffer22)
        bufferedAudio.appendSampleBuffer(sampleBuffer23)
        bufferedAudio.appendSampleBuffer(sampleBuffer24)
        bufferedAudio.appendSampleBuffer(sampleBuffer25)
        bufferedAudio.appendSampleBuffer(sampleBuffer26)
        #expect(bufferedAudio.numberOfBuffers() == 26)
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
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffer11)
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffer12)
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffer13)
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffer14)
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffer15)
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffer16)
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffer17)
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffer18)
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffer19)
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffer20)
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffer21)
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffer22)
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffer23)
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffer24)
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffer25)
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffer26)
        #expect(bufferedAudio.numberOfBuffers() == 0)
    }
    
    @Test
    func droppingAllTheFrames() async throws {
        let bufferedAudio = BufferedAudio(cameraId: .init(),
                                          name: "",
                                          latency: 0.1,
                                          processor: nil,
                                          manualOutput: true)

        let s1 = createSampleBuffer(presentationTimeStamp: 10.000)
        let s2 = createSampleBuffer(presentationTimeStamp: 10.000)
        let s3 = createSampleBuffer(presentationTimeStamp: 10.000)
        let s4 = createSampleBuffer(presentationTimeStamp: 10.000)
        let s5 = createSampleBuffer(presentationTimeStamp: 10.000)

        bufferedAudio.appendSampleBuffer(s1)
        bufferedAudio.appendSampleBuffer(s2)
        bufferedAudio.appendSampleBuffer(s3)
        bufferedAudio.appendSampleBuffer(s4)
        bufferedAudio.appendSampleBuffer(s5)

        #expect(bufferedAudio.numberOfBuffers() == 5)

        let out1 = bufferedAudio.getSampleBuffer(10.000)
        #expect(out1 === s1)

        let out2 = bufferedAudio.getSampleBuffer(10.021)
        #expect(out2 == s2)

        // Buffer should not discard all the frames
        #expect(bufferedAudio.numberOfBuffers() == 3)
    }
}
