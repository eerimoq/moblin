import AVFoundation
@testable import Moblin
import Testing

struct MpegTsSuite {
    @Test
    func firstPacketStuffing() {
        let stream = MpegTsPacketizedElementaryStream(
            streamId: 0xE0,
            presentationTimeStamp: CMTime(value: 0, timescale: 90000),
            decodeTimeStamp: .invalid,
            data: Data([0x65])
        )
        let packets = stream.arrayOfPackets(256, true, nil)
        #expect(packets.count == 1)
        #expect(packets[0].encode().count == MpegTsPacket.size)
    }

    @Test
    func firstPacketNoStuffing() {
        let stream = MpegTsPacketizedElementaryStream(
            streamId: 0xE0,
            presentationTimeStamp: CMTime(value: 0, timescale: 90000),
            decodeTimeStamp: .invalid,
            data: Data(repeating: 1, count: 168)
        )
        let packets = stream.arrayOfPackets(256, true, nil)
        #expect(packets.count == 1)
        #expect(packets[0].encode().count == MpegTsPacket.size)
    }

    @Test
    func twoPackets() {
        let stream = MpegTsPacketizedElementaryStream(
            streamId: 0xE0,
            presentationTimeStamp: CMTime(value: 0, timescale: 90000),
            decodeTimeStamp: .invalid,
            data: Data(repeating: 1, count: 169)
        )
        let packets = stream.arrayOfPackets(256, true, nil)
        #expect(packets.count == 2)
        #expect(packets[0].encode().count == MpegTsPacket.size)
        #expect(packets[1].encode().count == MpegTsPacket.size)
    }

    @Test
    func firstPacketWithClockReferenceStuffing() {
        let stream = MpegTsPacketizedElementaryStream(
            streamId: 0xE0,
            presentationTimeStamp: CMTime(value: 0, timescale: 90000),
            decodeTimeStamp: .invalid,
            data: Data(repeating: 1, count: 161)
        )
        let packets = stream.arrayOfPackets(256, true, 1234)
        #expect(packets.count == 1)
        #expect(packets[0].encode().count == MpegTsPacket.size)
    }

    @Test
    func firstPacketWithClockReferenceNoStuffing() {
        let stream = MpegTsPacketizedElementaryStream(
            streamId: 0xE0,
            presentationTimeStamp: CMTime(value: 0, timescale: 90000),
            decodeTimeStamp: .invalid,
            data: Data(repeating: 1, count: 162)
        )
        let packets = stream.arrayOfPackets(256, true, 1234)
        #expect(packets.count == 1)
        #expect(packets[0].encode().count == MpegTsPacket.size)
    }
}
