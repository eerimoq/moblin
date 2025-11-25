import AVFoundation
@testable import Moblin
import Testing

struct BufferedAudioSuite {
    @Test
    func processNormal() async throws {
        let bufferedAudio = createBufferedAudio()
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
    func processGap() async throws {
        let bufferedAudio = createBufferedAudio()
        let sampleBuffers = [
            createSampleBuffer(presentationTimeStamp: 1.000),
            createSampleBuffer(presentationTimeStamp: 1.021),
            createSampleBuffer(presentationTimeStamp: 1.210),
            createSampleBuffer(presentationTimeStamp: 1.231),
            createSampleBuffer(presentationTimeStamp: 1.252),
            createSampleBuffer(presentationTimeStamp: 1.273),
            createSampleBuffer(presentationTimeStamp: 1.294),
        ]
        appendSampleBuffers(bufferedAudio, sampleBuffers)
        #expect(bufferedAudio.numberOfBuffers() == 7)
        var timestamp = 1.000
        expectSequence(bufferedAudio, sampleBuffers, &timestamp, 0 ..< 2)
        for _ in 0 ..< 10 {
            #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffers[2])
            timestamp += 0.021
        }
        expectSequence(bufferedAudio, sampleBuffers, &timestamp, 3 ..< 7)
        #expect(bufferedAudio.numberOfBuffers() == 0)
    }

    @Test
    func processDriftChange() async throws {
        let bufferedAudio = createBufferedAudio()
        let sampleBuffers = [
            createSampleBuffer(presentationTimeStamp: 1.000),
            createSampleBuffer(presentationTimeStamp: 1.021),
            createSampleBuffer(presentationTimeStamp: 1.042),
            createSampleBuffer(presentationTimeStamp: 1.063),
            createSampleBuffer(presentationTimeStamp: 1.084),
            createSampleBuffer(presentationTimeStamp: 1.105),
            createSampleBuffer(presentationTimeStamp: 1.126),
            createSampleBuffer(presentationTimeStamp: 1.147),
            createSampleBuffer(presentationTimeStamp: 1.168),
            createSampleBuffer(presentationTimeStamp: 1.189),
            createSampleBuffer(presentationTimeStamp: 1.210),
            createSampleBuffer(presentationTimeStamp: 1.231),
            createSampleBuffer(presentationTimeStamp: 1.252),
            createSampleBuffer(presentationTimeStamp: 1.273),
            createSampleBuffer(presentationTimeStamp: 1.294),
        ]
        appendSampleBuffers(bufferedAudio, sampleBuffers)
        #expect(bufferedAudio.numberOfBuffers() == 15)
        var timestamp = 1.000
        expectSequence(bufferedAudio, sampleBuffers, &timestamp, 0 ..< 2)
        bufferedAudio.setDrift(drift: 0.1)
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffers[2])
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffers[2])
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffers[2])
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffers[2])
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffers[2])
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffers[2])
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffers[3])
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffers[4])
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffers[5])
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffers[6])
        timestamp += 0.021
        bufferedAudio.setDrift(drift: 0)
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffers[7])
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffers[12])
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffers[13])
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffers[14])
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffers[14])
        timestamp += 0.021
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffers[14])
        timestamp += 0.021
        #expect(bufferedAudio.numberOfBuffers() == 0)
    }

    @Test
    func oa6BadAudioTimestamps() async throws {
        let bufferedAudio = createBufferedAudio()
        let sampleBuffers = createOa6SampleBuffers()
        appendSampleBuffers(bufferedAudio, sampleBuffers)
        #expect(bufferedAudio.numberOfBuffers() == 26)
        var timestamp = 565.064
        expectSequence(bufferedAudio, sampleBuffers, &timestamp, 0 ..< 26)
        #expect(bufferedAudio.numberOfBuffers() == 0)
    }

    @Test
    func oa6BadAudioTimestampsOffsetOutputTime() async throws {
        let bufferedAudio = createBufferedAudio()
        let sampleBuffers = createOa6SampleBuffers()
        appendSampleBuffers(bufferedAudio, sampleBuffers)
        #expect(bufferedAudio.numberOfBuffers() == 26)
        var timestamp = 565.064 - 0.01
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffers[0])
        timestamp += 0.021
        expectSequence(bufferedAudio, sampleBuffers, &timestamp, 0 ..< 26)
        #expect(bufferedAudio.numberOfBuffers() == 0)
    }

    @Test
    func oa6BadAudioTimestampsOffsetOutputTime2() async throws {
        let bufferedAudio = createBufferedAudio()
        let sampleBuffers = createOa6SampleBuffers()
        appendSampleBuffers(bufferedAudio, sampleBuffers)
        #expect(bufferedAudio.numberOfBuffers() == 26)
        var timestamp = 565.064 + 0.01
        expectSequence(bufferedAudio, sampleBuffers, &timestamp, 0 ..< 26)
        #expect(bufferedAudio.numberOfBuffers() == 0)
    }

    @Test
    func oa6BadAudioTimestampsBigOffsetOutputTime() async throws {
        let bufferedAudio = createBufferedAudio()
        let sampleBuffers = createOa6SampleBuffers()
        appendSampleBuffers(bufferedAudio, sampleBuffers)
        #expect(bufferedAudio.numberOfBuffers() == 26)
        var timestamp = 565.064 - 0.2
        for _ in 0 ..< 10 {
            #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffers[0])
            timestamp += 0.021
        }
        expectSequence(bufferedAudio, sampleBuffers, &timestamp, 0 ..< 26)
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

private func expectSequence(_ bufferedAudio: BufferedAudio,
                            _ sampleBuffers: [CMSampleBuffer],
                            _ timestamp: inout Double,
                            _ range: Range<Int>)
{
    for i in range {
        #expect(bufferedAudio.getSampleBuffer(timestamp) === sampleBuffers[i],
                "Failed at index \(i), timestamp \(timestamp).")
        timestamp += 0.021
    }
}

private func createBufferedAudio() -> BufferedAudio {
    return BufferedAudio(cameraId: .init(),
                         name: "",
                         latency: 0.1,
                         processor: nil,
                         manualOutput: true)
}
