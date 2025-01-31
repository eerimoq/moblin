import CoreMedia
import Foundation

struct AdtsHeader: Equatable {
    static let size: Int = 7
    static let sync: UInt8 = 0xFF
    var sync = Self.sync
    var protectionAbsent = false
    var profile: UInt8 = 0
    var sampleFrequencyIndex: UInt8 = 0
    var channelConfiguration: UInt8 = 0
    var originalOrCopy = false
    var home = false
    var copyrightIdBit = false
    var copyrightIdStart = false
    var aacFrameLength: UInt16 = 0

    init?(data: Data) {
        guard AdtsHeader.size <= data.count else {
            return nil
        }
        sync = data[0]
        protectionAbsent = (data[1] & 0b0000_0001) == 1
        profile = data[2] >> 6 & 0b11
        sampleFrequencyIndex = (data[2] >> 2) & 0b0000_1111
        channelConfiguration = ((data[2] & 0b1) << 2) | data[3] >> 6
        originalOrCopy = (data[3] & 0b0010_0000) == 0b0010_0000
        home = (data[3] & 0b0001_0000) == 0b0001_0000
        copyrightIdBit = (data[3] & 0b0000_1000) == 0b0000_1000
        copyrightIdStart = (data[3] & 0b0000_0100) == 0b0000_0100
        aacFrameLength = UInt16(data[3] & 0b0000_0011) << 11 | UInt16(data[4]) << 3 | UInt16(data[5] >> 5)
        guard aacFrameLength > 0 else {
            return nil
        }
    }

    func makeFormatDescription() -> CMFormatDescription? {
        guard
            let type = AudioSpecificConfig.AudioObjectType(rawValue: profile + 1),
            let frequency = AudioSpecificConfig.SamplingFrequency(rawValue: sampleFrequencyIndex),
            let channel = AudioSpecificConfig.ChannelConfiguration(rawValue: channelConfiguration)
        else {
            return nil
        }
        var formatDescription: CMAudioFormatDescription?
        var audioStreamBasicDescription = AudioStreamBasicDescription(
            mSampleRate: frequency.sampleRate,
            mFormatID: kAudioFormatMPEG4AAC,
            mFormatFlags: UInt32(type.rawValue),
            mBytesPerPacket: 0,
            mFramesPerPacket: 1024,
            mBytesPerFrame: 0,
            mChannelsPerFrame: UInt32(channel.rawValue),
            mBitsPerChannel: 0,
            mReserved: 0
        )
        guard CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: &audioStreamBasicDescription,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &formatDescription
        ) == noErr else {
            return nil
        }
        return formatDescription
    }
}

class ADTSReader: Sequence {
    private var data: Data

    init(data: Data) {
        self.data = data
    }

    func makeIterator() -> ADTSReaderIterator {
        return ADTSReaderIterator(data: data)
    }
}

struct ADTSReaderIterator: IteratorProtocol {
    private let data: Data
    private var cursor: Int = 0

    init(data: Data) {
        self.data = data
    }

    mutating func next() -> Int? {
        guard cursor < data.count else {
            return nil
        }
        guard let header = AdtsHeader(data: data.advanced(by: cursor)) else {
            return nil
        }
        defer {
            cursor += Int(header.aacFrameLength)
        }
        return Int(header.aacFrameLength)
    }
}
