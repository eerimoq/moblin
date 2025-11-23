import AVFoundation
@testable import Moblin
import Testing

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
        let sampleBuffers = createOa6SampleBuffers()
        appendSampleBuffers(bufferedAudio, sampleBuffers)
        #expect(bufferedAudio.numberOfBuffers() == 26)
        var timestamp = 565.064
        for i in 0 ..< 26 {
            #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffers[i])
            timestamp += 0.021
        }
        #expect(bufferedAudio.numberOfBuffers() == 0)
    }

    @Test
    func oa6BadAudioTimestampsOffsetOutputTime() async throws {
        let bufferedAudio = BufferedAudio(cameraId: .init(),
                                          name: "",
                                          latency: 0.1,
                                          processor: nil,
                                          manualOutput: true)
        let sampleBuffers = createOa6SampleBuffers()
        appendSampleBuffers(bufferedAudio, sampleBuffers)
        #expect(bufferedAudio.numberOfBuffers() == 26)
        var timestamp = 565.064 - 0.01
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffers[0])
        timestamp += 0.021
        for i in 0 ..< 26 {
            #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffers[i])
            timestamp += 0.021
        }
        #expect(bufferedAudio.numberOfBuffers() == 0)
    }

    @Test
    func oa6BadAudioTimestampsOffsetOutputTime2() async throws {
        let bufferedAudio = BufferedAudio(cameraId: .init(),
                                          name: "",
                                          latency: 0.1,
                                          processor: nil,
                                          manualOutput: true)
        let sampleBuffers = createOa6SampleBuffers()
        appendSampleBuffers(bufferedAudio, sampleBuffers)
        #expect(bufferedAudio.numberOfBuffers() == 26)
        var timestamp = 565.064 + 0.01
        for i in 0 ..< 26 {
            #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffers[i])
            timestamp += 0.021
        }
        #expect(bufferedAudio.numberOfBuffers() == 0)
    }

    @Test
    func oa6BadAudioTimestampsBigOffsetOutputTime() async throws {
        let bufferedAudio = BufferedAudio(cameraId: .init(),
                                          name: "",
                                          latency: 0.1,
                                          processor: nil,
                                          manualOutput: true)
        let sampleBuffers = createOa6SampleBuffers()
        appendSampleBuffers(bufferedAudio, sampleBuffers)
        #expect(bufferedAudio.numberOfBuffers() == 26)
        var timestamp = 565.064 - 0.2
        for _ in 0 ..< 10 {
            #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffers[0])
            timestamp += 0.021
        }
        for i in 0 ..< 26 {
            #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffers[i])
            timestamp += 0.021
        }
        #expect(bufferedAudio.numberOfBuffers() == 0)
    }
}

private func createSampleBuffer(presentationTimeStamp: Double) -> CMSampleBuffer {
    let format = AVAudioFormat(commonFormat: .pcmFormatInt16,
                               sampleRate: 48000,
                               channels: 1,
                               interleaved: false)!
    return CMSampleBuffer.createSilent(format, CMTime(seconds: presentationTimeStamp), 1024)!
}

private func createOa6SampleBuffers() -> [CMSampleBuffer] {
    return [
        createSampleBuffer(presentationTimeStamp: 565.064),
        createSampleBuffer(presentationTimeStamp: 565.097),
        createSampleBuffer(presentationTimeStamp: 565.097),
        createSampleBuffer(presentationTimeStamp: 565.131),
        createSampleBuffer(presentationTimeStamp: 565.164),
        createSampleBuffer(presentationTimeStamp: 565.164),
        createSampleBuffer(presentationTimeStamp: 565.197),
        createSampleBuffer(presentationTimeStamp: 565.197),
        createSampleBuffer(presentationTimeStamp: 565.231),
        createSampleBuffer(presentationTimeStamp: 565.231),
        createSampleBuffer(presentationTimeStamp: 565.264),
        createSampleBuffer(presentationTimeStamp: 565.298),
        createSampleBuffer(presentationTimeStamp: 565.331),
        createSampleBuffer(presentationTimeStamp: 565.331),
        createSampleBuffer(presentationTimeStamp: 565.364),
        createSampleBuffer(presentationTimeStamp: 565.398),
        createSampleBuffer(presentationTimeStamp: 565.398),
        createSampleBuffer(presentationTimeStamp: 565.431),
        createSampleBuffer(presentationTimeStamp: 565.464),
        createSampleBuffer(presentationTimeStamp: 565.464),
        createSampleBuffer(presentationTimeStamp: 565.498),
        createSampleBuffer(presentationTimeStamp: 565.531),
        createSampleBuffer(presentationTimeStamp: 565.531),
        createSampleBuffer(presentationTimeStamp: 565.531),
        createSampleBuffer(presentationTimeStamp: 565.565),
        createSampleBuffer(presentationTimeStamp: 565.598),
    ]
}

private func appendSampleBuffers(_ bufferedAudio: BufferedAudio,
                                 _ sampleBuffers: [CMSampleBuffer])
{
    for sampleBuffer in sampleBuffers {
        bufferedAudio.appendSampleBuffer(sampleBuffer)
    }
}
