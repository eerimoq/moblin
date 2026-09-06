import Foundation
@testable import Moblin
import Testing

private let noon = Date(timeIntervalSince1970: 1_755_864_000)

private func clock(_ hours: Int, _ minutes: Int, _ seconds: Int) -> Date {
    calendar.startOfDay(for: noon)
        .addingTimeInterval(Double(3600 * hours + 60 * minutes + seconds))
}

struct NalUnitSeiSuite {
    @Test
    func hevcTimeCodePayloadEncode() {
        let timeCode = HevcSeiPayloadTimeCode(clock: clock(12, 34, 56), frame: 7)
        #expect(timeCode.encode() == Data([0x70, 0x40, 0x3F, 0x11, 0x30, 0x10]))
    }

    @Test
    func hevcTimeCodePayloadDecode() throws {
        let reader = NalUnitReader(data: Data([0x70, 0x40, 0x3F, 0x11, 0x30, 0x10]))
        let timeCode = try #require(HevcSeiPayloadTimeCode(reader: reader))
        #expect(timeCode.hours == 12)
        #expect(timeCode.minutes == 34)
        #expect(timeCode.seconds == 56)
        #expect(timeCode.frame == 7)
    }

    @Test(arguments: [(0, 0, 0, UInt32(0)),
                      (23, 59, 59, UInt32(59)),
                      (12, 34, 56, UInt32(7)),
                      (1, 2, 3, UInt32(255)),
                      (9, 8, 7, UInt32(511))])
    func hevcTimeCodePayloadRoundTrip(hours: Int, minutes: Int, seconds: Int, frame: UInt32) throws {
        let encoded = HevcSeiPayloadTimeCode(clock: clock(hours, minutes, seconds), frame: frame).encode()
        let decoded = try #require(HevcSeiPayloadTimeCode(reader: NalUnitReader(data: encoded)))
        #expect(decoded.hours == UInt8(hours))
        #expect(decoded.minutes == UInt8(minutes))
        #expect(decoded.seconds == UInt8(seconds))
        #expect(decoded.frame == frame)
    }

    @Test
    func hevcTimeCodePayloadMakeClock() {
        let timeCode = HevcSeiPayloadTimeCode(clock: clock(12, 34, 56), frame: 7)
        let (decodedClock, frame) = timeCode.makeClock()
        #expect(decodedClock.timeIntervalSince1970
            .truncatingRemainder(dividingBy: 86400) == Double(12 * 3600 + 34 * 60 + 56))
        #expect(frame == 7)
    }

    @Test
    func hevcNalUnitRoundTrip() throws {
        let timeCode = HevcSeiPayloadTimeCode(clock: clock(12, 34, 56), frame: 7)
        let sei = HevcNalUnitSei(payload: .timeCode(timeCode))
        let encoded = HevcNalUnit(type: .prefixSeiNut, temporalIdPlusOne: 1, payload: .prefixSeiNut(sei))
            .encode()
        #expect(encoded.prefix(2) == Data([0x4E, 0x01]))
        #expect(encoded[2] == 136)
        #expect(encoded[3] == 6)
        let decoded = try #require(HevcNalUnit(data: encoded, offset: 0))
        #expect(decoded.header.type == .prefixSeiNut)
        #expect(decoded.header.temporalIdPlusOne == 1)
        guard case let .prefixSeiNut(decodedSei) = decoded.payload,
              case let .timeCode(decodedTimeCode) = decodedSei.payload
        else {
            Issue.record("Not a time code SEI")
            return
        }
        #expect(decodedTimeCode.hours == 12)
        #expect(decodedTimeCode.minutes == 34)
        #expect(decodedTimeCode.seconds == 56)
        #expect(decodedTimeCode.frame == 7)
    }

    @Test
    func hevcNalUnitEmulationPreventionByteInserted() {
        let timeCode = HevcSeiPayloadTimeCode(clock: clock(0, 0, 0), frame: 0)
        let sei = HevcNalUnitSei(payload: .timeCode(timeCode))
        let encoded = HevcNalUnit(type: .prefixSeiNut, temporalIdPlusOne: 1, payload: .prefixSeiNut(sei))
            .encode()
        #expect(encoded == Data([0x4E, 0x01, 0x88, 0x06, 0x70, 0x40, 0x00, 0x00, 0x03, 0x00, 0x10, 0x80]))
    }

    @Test
    func hevcNalUnitNoEmulationPreventionByteOnTheHour() {
        let timeCode = HevcSeiPayloadTimeCode(clock: clock(12, 0, 0), frame: 0)
        let sei = HevcNalUnitSei(payload: .timeCode(timeCode))
        let encoded = HevcNalUnit(type: .prefixSeiNut, temporalIdPlusOne: 1, payload: .prefixSeiNut(sei))
            .encode()
        #expect(encoded == Data([0x4E, 0x01, 0x88, 0x06, 0x70, 0x40, 0x00, 0x00, 0x30, 0x10, 0x80]))
    }

    @Test(arguments: [(0, 0, 0, UInt32(0)),
                      (0, 1, 0, UInt32(0)),
                      (0, 2, 8, UInt32(32)),
                      (23, 59, 59, UInt32(59))])
    func hevcNalUnitRoundTripWithEmulationPreventionBytes(hours: Int,
                                                          minutes: Int,
                                                          seconds: Int,
                                                          frame: UInt32) throws
    {
        let timeCode = HevcSeiPayloadTimeCode(clock: clock(hours, minutes, seconds), frame: frame)
        let sei = HevcNalUnitSei(payload: .timeCode(timeCode))
        let encoded = HevcNalUnit(type: .prefixSeiNut, temporalIdPlusOne: 1, payload: .prefixSeiNut(sei))
            .encode()
        let decoded = try #require(HevcNalUnit(data: encoded, offset: 0))
        guard case let .prefixSeiNut(decodedSei) = decoded.payload,
              case let .timeCode(decodedTimeCode) = decodedSei.payload
        else {
            Issue.record("Not a time code SEI")
            return
        }
        #expect(decodedTimeCode.hours == UInt8(hours))
        #expect(decodedTimeCode.minutes == UInt8(minutes))
        #expect(decodedTimeCode.seconds == UInt8(seconds))
        #expect(decodedTimeCode.frame == frame)
    }

    @Test(arguments: [(0, 0, 0, UInt32(0)),
                      (23, 59, 59, UInt32(59)),
                      (12, 34, 56, UInt32(7))])
    func avcNalUnitRoundTrip(hours: Int, minutes: Int, seconds: Int, frame: UInt32) throws {
        let pictureTiming = AvcSeiPayloadPictureTiming(clock: clock(hours, minutes, seconds), frame: frame)
        let sei = AvcNalUnitSei(payload: .pictureTiming(pictureTiming))
        let encoded = AvcNalUnit(type: .sei, payload: .sei(sei)).encode()
        #expect(encoded[0] == 6)
        #expect(encoded[1] == 1)
        let decoded = try #require(AvcNalUnit(data: encoded, offset: 0))
        #expect(decoded.header.type == .sei)
        guard case let .sei(decodedSei) = decoded.payload,
              case let .pictureTiming(decodedPictureTiming) = decodedSei.payload
        else {
            Issue.record("Not a picture timing SEI")
            return
        }
        #expect(decodedPictureTiming.hours == UInt8(hours))
        #expect(decodedPictureTiming.minutes == UInt8(minutes))
        #expect(decodedPictureTiming.seconds == UInt8(seconds))
        #expect(decodedPictureTiming.frame == frame)
    }
}
