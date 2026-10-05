import Foundation
@testable import Moblin
import Testing

struct Insta360ProtocolSuite {
    @Test
    func parsesFragmentedAndCoalescedCameraPackets() throws {
        let wire = Data([
            17, 0, 0, 0, 6, 0, 0, 115, 121, 78, 99, 101, 78, 100, 105, 110, 83,
            7, 0, 0, 0, 5, 0, 0,
            16, 0, 0, 0, 4, 0, 0, 200, 0, 2, 3, 2, 1, 128, 0, 0,
            22, 0, 0, 0, 1, 0, 0, 9, 8, 7, 6, 0, 0, 0, 0, 0, 0, 0, 1, 38, 1, 128,
        ])
        let expected: [Insta360Packet] = [
            .sync, .keepAlive, .response(code: 200, sequence: 0x010203),
            .video(Data([0, 0, 1, 38, 1, 128])),
        ]
        for split in 0 ... wire.count {
            var parser = Insta360Protocol()
            let first = try parser.append(Data(wire.prefix(split)))
            let second = try parser.append(Data(wire.dropFirst(split)))
            #expect(first + second == expected)
        }
        var parser = Insta360Protocol()
        var packets: [Insta360Packet] = []
        for byte in wire {
            packets += try parser.append(Data([byte]))
        }
        #expect(packets == expected)
    }

    @Test(arguments: [0, 3, 6, 16 * 1024 * 1024 + 1, Int(UInt32.max)])
    func rejectsInvalidPacketLengthBeforeWaitingForPayload(_ count: Int) {
        var count = UInt32(count).littleEndian
        let data = withUnsafeBytes(of: &count) { Data($0) }
        #expect(throws: Insta360ProtocolError.self) {
            var parser = Insta360Protocol()
            _ = try parser.append(data)
        }
    }

    @Test
    func rejectsTruncatedVideoHeader() {
        #expect(throws: Insta360ProtocolError.self) {
            var parser = Insta360Protocol()
            _ = try parser.append(Data([7, 0, 0, 0, 1, 0, 0]))
        }
    }

    @Test
    func skipsUnknownPacketsWithoutLosingFraming() throws {
        var parser = Insta360Protocol()
        #expect(try parser.append(Data([8, 0, 0, 0, 9, 0, 0, 42, 7, 0, 0, 0, 5, 0, 0]))
            == [.unknown, .keepAlive])
    }

    @Test
    func encodesPreviewCommandsWithLittleEndianLengthAndSequence() {
        #expect(Insta360Protocol.command(id: 1, sequence: 0x010203)
            == Data([16, 0, 0, 0, 4, 0, 0, 1, 0, 2, 3, 2, 1, 128, 0, 0]))
        #expect(Insta360Protocol.command(id: 2, sequence: 1)
            == Data([16, 0, 0, 0, 4, 0, 0, 2, 0, 2, 1, 0, 0, 128, 0, 0]))
    }

    @Test
    func assemblesFramesAcrossEveryAnnexBBoundary() throws {
        let vps = Data([64, 1, 12, 1])
        let firstSlice = Data([38, 1, 128, 42])
        let secondSlice = Data([38, 1, 0, 42])
        let nextPicture = Data([2, 1, 128, 43])
        let wire = Data([0, 0, 0, 1]) + vps + Data([0, 0, 1]) + firstSlice
            + Data([0, 0, 0, 1]) + secondSlice + Data([0, 0, 1]) + nextPicture
        let expected = [Insta360HevcFrame(nalUnits: [vps, firstSlice, secondSlice]),
                        Insta360HevcFrame(nalUnits: [nextPicture])]
        for split in 0 ... wire.count {
            var stream = Insta360HevcStream()
            var frames = try stream.append(Data(wire.prefix(split)))
            frames += try stream.append(Data(wire.dropFirst(split)))
            frames += try stream.finish()
            #expect(frames == expected)
            #expect(frames.first?.isKeyframe == true)
            #expect(frames.last?.isKeyframe == false)
        }
        var stream = Insta360HevcStream()
        var frames: [Insta360HevcFrame] = []
        for byte in wire {
            frames += try stream.append(Data([byte]))
        }
        frames += try stream.finish()
        #expect(frames == expected)
    }

    @Test
    func keepsNewParameterSetsWithTheFollowingPicture() throws {
        var stream = Insta360HevcStream()
        let firstPicture = Data([38, 1, 128, 42])
        let vps = Data([64, 1, 12, 1])
        let nextPicture = Data([38, 1, 128, 43])
        let start = Data([0, 0, 1])
        var frames = try stream.append(start + firstPicture + start + vps + start + nextPicture)
        frames += try stream.finish()
        #expect(frames == [Insta360HevcFrame(nalUnits: [firstPicture]),
                           Insta360HevcFrame(nalUnits: [vps, nextPicture])])
    }

    @Test
    func emitsFourByteBigEndianNalLengthsForVideoToolbox() {
        let frame = Insta360HevcFrame(nalUnits: [Data([38, 1, 128, 42]), Data([38, 1, 0, 42])])
        #expect(frame.lengthPrefixedData()
            == Data([0, 0, 0, 4, 38, 1, 128, 42, 0, 0, 0, 4, 38, 1, 0, 42]))
    }

    @Test
    func boundsUnterminatedVideoData() {
        #expect(throws: Insta360ProtocolError.self) {
            var stream = Insta360HevcStream()
            _ = try stream.append(Data([0, 0, 1, 38, 1]) + Data(repeating: 42, count: 16 * 1024 * 1024))
        }
    }

    @Test
    func rejectsTruncatedSliceInsteadOfReadingPastBuffer() {
        #expect(throws: Insta360ProtocolError.self) {
            var stream = Insta360HevcStream()
            _ = try stream.append(Data([0, 0, 1, 38, 1, 0, 0, 1, 64, 1, 1]))
        }
    }
}
