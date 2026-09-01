import AVFoundation
@testable import Moblin
import Testing

private let audioSampleRate = 48000.0
private let audioFramesPerBuffer = 1024
private let videoFrameDuration = CMTime(value: 1, timescale: 30)
private let toneAmplitude = 0.3
private let recordingLength = 3.0
private let startTime = 1000.0

private final class RecorderTester: RecorderDelegate, @unchecked Sendable {
    private let finished = DispatchSemaphore(value: 0)
    private let toneTime: Double
    let url: URL

    init(toneTime: Double) {
        self.toneTime = toneTime
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("recorder-suite-\(UUID().uuidString).mp4")
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    func record(audioDelay: (Double) -> Double) -> Bool {
        let recorder = Recorder()
        recorder.delegate = self
        recorder.startRunning(url: url,
                              replay: false,
                              audioOutputSettings: [
                                  AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                                  AVSampleRateKey: 48000,
                                  AVNumberOfChannelsKey: 0,
                              ],
                              videoOutputSettings: [
                                  AVVideoCodecKey: AVVideoCodecType.h264,
                                  AVVideoWidthKey: 0,
                                  AVVideoHeightKey: 0,
                              ])
        processorPipelineQueue.sync {}
        appendSampleBuffers(recorder, audioDelay)
        recorder.stopRunning()
        guard finished.wait(timeout: .now() + 10) == .success else {
            return false
        }
        return waitForFileWritten()
    }

    func recorderInitSegment(data _: Data) {}

    func recorderDataSegment(segment _: RecorderDataSegment) {}

    func recorderFinished() {
        finished.signal()
    }

    private func appendSampleBuffers(_ recorder: Recorder, _ audioDelay: (Double) -> Double) {
        var audioTime = 0.0
        var videoTime = 0.0
        var audioFrame = 0
        while videoTime < recordingLength {
            if audioTime <= videoTime {
                recorder.appendAudio(
                    createAudioSampleBuffer(audioFrame, toneTime),
                    CMTime(seconds: startTime + audioTime + audioDelay(audioTime))
                )
                audioFrame += audioFramesPerBuffer
                audioTime = Double(audioFrame) / audioSampleRate
            } else {
                recorder.appendVideo(createVideoSampleBuffer(CMTime(seconds: startTime + videoTime)))
                videoTime += videoFrameDuration.seconds
                Thread.sleep(forTimeInterval: 0.015)
            }
        }
    }

    private func waitForFileWritten() -> Bool {
        var latestFileSize = -1
        for _ in 0 ..< 100 {
            Thread.sleep(forTimeInterval: 0.05)
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let fileSize = attributes[.size] as? Int
            else {
                continue
            }
            if fileSize > 0, fileSize == latestFileSize {
                return true
            }
            latestFileSize = fileSize
        }
        return false
    }
}

private func createAudioSampleBuffer(_ firstFrame: Int, _ toneTime: Double) -> CMSampleBuffer {
    let format = AVAudioFormat(commonFormat: .pcmFormatInt16,
                               sampleRate: audioSampleRate,
                               channels: 1,
                               interleaved: true)!
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: UInt32(audioFramesPerBuffer))!
    buffer.frameLength = UInt32(audioFramesPerBuffer)
    let samples = buffer.int16ChannelData![0]
    for index in 0 ..< audioFramesPerBuffer {
        let frame = firstFrame + index
        if Double(frame) / audioSampleRate >= toneTime {
            samples[index] = Int16(toneAmplitude * sin(2 * .pi * 1000 * Double(frame) / audioSampleRate) *
                32767)
        } else {
            samples[index] = 0
        }
    }
    return buffer.makeSampleBuffer(CMTime(seconds: 0))!
}

private func createVideoSampleBuffer(_ presentationTimeStamp: CMTime) -> CMSampleBuffer {
    var pixelBuffer: CVPixelBuffer?
    CVPixelBufferCreate(kCFAllocatorDefault,
                        320,
                        180,
                        kCVPixelFormatType_32BGRA,
                        [kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary] as CFDictionary,
                        &pixelBuffer)
    var formatDescription: CMVideoFormatDescription?
    CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                 imageBuffer: pixelBuffer!,
                                                 formatDescriptionOut: &formatDescription)
    var timingInfo = CMSampleTimingInfo(duration: videoFrameDuration,
                                        presentationTimeStamp: presentationTimeStamp,
                                        decodeTimeStamp: .invalid)
    var sampleBuffer: CMSampleBuffer?
    CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                       imageBuffer: pixelBuffer!,
                                       dataReady: true,
                                       makeDataReadyCallback: nil,
                                       refcon: nil,
                                       formatDescription: formatDescription!,
                                       sampleTiming: &timingInfo,
                                       sampleBufferOut: &sampleBuffer)
    return sampleBuffer!
}

private func loadTrackDuration(_ url: URL, _ mediaType: AVMediaType) async throws -> Double? {
    let asset = AVURLAsset(url: url)
    guard let track = try await asset.loadTracks(withMediaType: mediaType).first else {
        return nil
    }
    return try await track.load(.timeRange).duration.seconds
}

private func loadToneTime(_ url: URL) async throws -> Double? {
    let asset = AVURLAsset(url: url)
    guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
        return nil
    }
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
        AVFormatIDKey: Int(kAudioFormatLinearPCM),
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsNonInterleaved: false,
        AVSampleRateKey: audioSampleRate,
        AVNumberOfChannelsKey: 1,
    ])
    reader.add(output)
    reader.startReading()
    while let sampleBuffer = output.copyNextSampleBuffer() {
        var toneFrame: Int?
        try? sampleBuffer.withAudioBufferList { list, _ in
            guard let samples = list[0].mData?.assumingMemoryBound(to: Int16.self) else {
                return
            }
            for index in 0 ..< sampleBuffer.numSamples where abs(Int(samples[index])) > 3000 {
                toneFrame = index
                break
            }
        }
        if let toneFrame {
            return sampleBuffer.presentationTimeStamp.seconds + Double(toneFrame) / audioSampleRate
        }
    }
    return nil
}

@Suite(.serialized)
struct RecorderSuite {
    @Test
    func recordsAudioAndVideo() async throws {
        let tester = RecorderTester(toneTime: 1.0)
        #expect(tester.record(audioDelay: { _ in 0 }))
        let videoDuration = try await loadTrackDuration(tester.url, .video)
        let audioDuration = try await loadTrackDuration(tester.url, .audio)
        #expect(videoDuration ?? 0 > 1.5)
        #expect(audioDuration ?? 0 > 1.5)
        let toneTime = try #require(try await loadToneTime(tester.url))
        #expect(isEqual(toneTime, 1.0, epsilon: 0.06), "Tone at \(toneTime)")
    }

    @Test
    func positiveAudioDelayDelaysAudio() async throws {
        let tester = RecorderTester(toneTime: 1.0)
        #expect(tester.record(audioDelay: { _ in 0.5 }))
        let toneTime = try #require(try await loadToneTime(tester.url))
        #expect(isEqual(toneTime, 1.5, epsilon: 0.06), "Tone at \(toneTime)")
    }

    @Test
    func audioGoingBackInTimeIsDropped() async throws {
        let tester = RecorderTester(toneTime: 2.0)
        #expect(tester.record(audioDelay: { $0 < 1.0 ? 0 : -0.5 }))
        let toneTime = try #require(try await loadToneTime(tester.url))
        #expect(isEqual(toneTime, 1.5, epsilon: 0.06), "Tone at \(toneTime)")
    }

    @Test
    func negativeAudioDelayAdvancesAudio() async throws {
        let tester = RecorderTester(toneTime: 1.0)
        #expect(tester.record(audioDelay: { _ in -0.5 }))
        let toneTime = try #require(try await loadToneTime(tester.url))
        #expect(isEqual(toneTime, 0.5, epsilon: 0.06), "Tone at \(toneTime)")
    }
}
