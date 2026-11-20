import AVFoundation
@testable import Moblin
import Testing

struct RtmpMediaSuite {
    enum Track {
        case audio
        case video
    }

    struct TimestampsCase: CustomTestStringConvertible {
        let name: String
        let inputs: [(Track, Double)]
        let expected: [UInt32?]

        var testDescription: String {
            name
        }
    }

    @Test(arguments: [
        TimestampsCase(name: "first is zero",
                       inputs: [(.audio, 10)],
                       expected: [0]),
        TimestampsCase(name: "deltas in milliseconds",
                       inputs: [(.audio, 10), (.audio, 10.5), (.audio, 11.25)],
                       expected: [0, 500, 750]),
        TimestampsCase(name: "fractions are carried over",
                       inputs: [(.video, 10), (.video, 10.03125), (.video, 10.0625), (.video, 10.09375),
                                (.video, 10.125)],
                       expected: [0, 31, 31, 31, 32]),
        TimestampsCase(name: "before base is dropped",
                       inputs: [(.audio, 10), (.audio, 9.5), (.audio, 10.5)],
                       expected: [0, nil, 500]),
        TimestampsCase(name: "out of order is dropped",
                       inputs: [(.audio, 10), (.audio, 10.5), (.audio, 10.25), (.audio, 11)],
                       expected: [0, 500, nil, 500]),
        TimestampsCase(name: "base is shared",
                       inputs: [(.video, 10), (.audio, 9.5), (.audio, 10.25), (.audio, 10.5)],
                       expected: [0, nil, 0, 250]),
        TimestampsCase(name: "tracks have separate deltas",
                       inputs: [(.audio, 10), (.video, 10.5), (.audio, 10.25), (.video, 11)],
                       expected: [0, 0, 250, 500]),
    ])
    func timestamps(_ testCase: TimestampsCase) {
        var timestamps = RtmpTimestamps()
        let actual = testCase.inputs.map { track, timestamp in
            switch track {
            case .audio:
                timestamps.audio(timestamp)
            case .video:
                timestamps.video(timestamp)
            }
        }
        #expect(actual == testCase.expected)
    }

    @Test
    func aacSequenceHeader() {
        #expect(makeRtmpAudioSequenceHeader(makeAacFormat()) == Data([0xAF, 0x00, 0x11, 0x90]))
    }

    @Test
    func opusSequenceHeader() {
        #expect(makeRtmpAudioSequenceHeader(makeOpusFormat())
            == Data([0x90]) + "OpusOpusHead".utf8Data + Data([1, 2, 0, 0, 0, 0, 0xBB, 0x80, 0, 0, 0]))
    }

    @Test
    func aacFrame() {
        #expect(makeRtmpAudioFrame(makeAudioBuffer(format: makeAacFormat(), payload: Data([1, 2, 3])))
            == Data([0xAF, 0x01, 1, 2, 3]))
    }

    @Test
    func opusFrame() {
        #expect(makeRtmpAudioFrame(makeAudioBuffer(format: makeOpusFormat(), payload: Data([1, 2, 3])))
            == Data([0x91]) + "Opus".utf8Data + Data([1, 2, 3]))
    }

    @Test
    func h264SequenceHeader() throws {
        let formatDescription = try makeH264FormatDescription()
        let avcC = try #require(MpegTsVideoConfigAvc.getAvcC(formatDescription))
        #expect(makeRtmpVideoSequenceHeader(.h264, formatDescription) == Data([0x17, 0, 0, 0, 0]) + avcC)
    }

    @Test
    func hevcSequenceHeaderWithoutHvcC() throws {
        #expect(try makeRtmpVideoSequenceHeader(.hevc, makeH264FormatDescription()) == nil)
    }

    struct VideoFrameCase: CustomTestStringConvertible {
        let format: VideoEncoderSettings.Format
        let isSync: Bool
        let decodeTimeStamp: CMTime
        let expectedHeader: Data

        var testDescription: String {
            "\(format), sync \(isSync), dts \(decodeTimeStamp.seconds)"
        }
    }

    @Test(arguments: [
        VideoFrameCase(format: .h264,
                       isSync: true,
                       decodeTimeStamp: mediaTime(10240),
                       expectedHeader: Data([0x17, 0x01, 0, 0, 62])),
        VideoFrameCase(format: .h264,
                       isSync: false,
                       decodeTimeStamp: mediaTime(10240),
                       expectedHeader: Data([0x27, 0x01, 0, 0, 62])),
        VideoFrameCase(format: .h264,
                       isSync: true,
                       decodeTimeStamp: .invalid,
                       expectedHeader: Data([0x17, 0x01, 0, 0, 0])),
        VideoFrameCase(format: .hevc,
                       isSync: true,
                       decodeTimeStamp: mediaTime(10240),
                       expectedHeader: Data([0x91]) + "hvc1".utf8Data + Data([0, 0, 62])),
        VideoFrameCase(format: .hevc,
                       isSync: false,
                       decodeTimeStamp: mediaTime(10240),
                       expectedHeader: Data([0xA1]) + "hvc1".utf8Data + Data([0, 0, 62])),
    ])
    func videoFrame(_ testCase: VideoFrameCase) throws {
        let sampleBuffer = try makeVideoSampleBuffer(formatDescription: makeH264FormatDescription(),
                                                     decodeTimeStamp: testCase.decodeTimeStamp,
                                                     presentationTimeStamp: mediaTime(10304),
                                                     isSync: testCase.isSync,
                                                     payload: Data([0, 0, 0, 1, 7]))
        #expect(makeRtmpVideoFrame(testCase.format, sampleBuffer, Data([0, 0, 0, 1, 7]))
            == testCase.expectedHeader + Data([0, 0, 0, 1, 7]))
    }

    @Test
    func videoFrameWithNegativeCompositionTime() throws {
        let sampleBuffer = try makeVideoSampleBuffer(formatDescription: makeH264FormatDescription(),
                                                     decodeTimeStamp: mediaTime(10304),
                                                     presentationTimeStamp: mediaTime(10240),
                                                     isSync: true,
                                                     payload: Data([7]))
        #expect(makeRtmpVideoFrame(.h264, sampleBuffer, Data([7])) == Data([0x17, 0x01, 0xFF, 0xFF, 0xC2, 7]))
    }
}
