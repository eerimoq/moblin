import AVFoundation
@testable import Moblin
import Testing

struct TSTimestampSuite {
    @Test
    func encodeKnownValue() {
        #expect(TSTimestamp.encode(0x1_2345_6789, 0x20) == Data([0x29, 0x8D, 0x15, 0xCF, 0x13]))
    }

    @Test
    func encodeMaximumValue() {
        #expect(TSTimestamp.encode(0x1_FFFF_FFFF, 0x30) == Data([0x3F, 0xFF, 0xFF, 0xFF, 0xFF]))
    }

    @Test
    func encodeZero() {
        #expect(TSTimestamp.encode(0, 0x10) == Data([0x11, 0x00, 0x01, 0x00, 0x01]))
    }

    @Test
    func encodeWrapsAt33Bits() {
        let uptime30Hours = Int64(30 * 3600 * 90000)
        let encoded = TSTimestamp.encode(uptime30Hours, 0x20)
        #expect(encoded[0] & 0xF0 == 0x20)
        #expect(TSTimestamp.decode(encoded) == uptime30Hours & 0x1_FFFF_FFFF)
    }

    @Test
    func encodeNegativeValue() {
        let encoded = TSTimestamp.encode(-1, 0x20)
        #expect(encoded == Data([0x2F, 0xFF, 0xFF, 0xFF, 0xFF]))
        #expect(TSTimestamp.decode(encoded) == 0x1_FFFF_FFFF)
    }

    @Test
    func roundTrip() {
        for value: Int64 in [0, 1, 90000, 0x1234_5678, 0xFFFF_FFFF, 0x1_0000_0000, 0x1_FFFF_FFFE] {
            #expect(TSTimestamp.decode(TSTimestamp.encode(value, 0x20)) == value)
        }
    }

    @Test
    func decodeIgnoresMarkerBits() {
        #expect(TSTimestamp.decode(Data([0xF1, 0x00, 0x01, 0x00, 0x01])) == 0)
    }

    @Test
    func decodeAtOffset() {
        let data = TSTimestamp.encode(1000, 0x30) + TSTimestamp.encode(900, 0x10)
        #expect(TSTimestamp.decode(data, offset: 0) == 1000)
        #expect(TSTimestamp.decode(data, offset: TSTimestamp.dataSize) == 900)
    }

    @Test
    func decodeTooShort() {
        #expect(TSTimestamp.decode(Data()) == nil)
        #expect(TSTimestamp.decode(Data([0x21, 0x00, 0x01, 0x00])) == nil)
        #expect(TSTimestamp.decode(Data([0x21, 0x00, 0x01, 0x00, 0x01]), offset: 1) == nil)
    }

    @Test
    func optionalHeaderTruncatedTimestamps() throws {
        var header = try OptionalHeader(data: Data([0x80, 0xC0, 0x03, 0x31, 0x00, 0x01]))
        #expect(header.getPresentationTimeStamp() == .invalid)
        #expect(header.getDecodeTimeStamp() == .invalid)
        header = try OptionalHeader(data: Data([0x80, 0xC0, 0x05]) + TSTimestamp.encode(1000, 0x30))
        #expect(header.getPresentationTimeStamp() == CMTime(value: 1000, timescale: 90000))
        #expect(header.getDecodeTimeStamp() == .invalid)
    }

    @Test
    func optionalHeaderRoundTrip() throws {
        var header = OptionalHeader()
        header.setTimestamp(CMTime(value: 1000, timescale: 90000), CMTime(value: 900, timescale: 90000))
        let decoded = try OptionalHeader(data: header.encode())
        #expect(decoded.getPresentationTimeStamp() == CMTime(value: 1000, timescale: 90000))
        #expect(decoded.getDecodeTimeStamp() == CMTime(value: 900, timescale: 90000))
    }
}
