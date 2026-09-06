import Foundation
@testable import Moblin
import Testing

struct NalUnitWriterSuite {
    @Test
    func writeBitMsbFirst() {
        let writer = NalUnitWriter()
        for value in [true, false, true, false, false, true, false, true] {
            writer.writeBit(value)
        }
        #expect(writer.data == Data([0xA5]))
    }

    @Test
    func writeBitsAcrossByteBoundary() {
        let writer = NalUnitWriter()
        writer.writeBits(0x0B, count: 4)
        writer.writeBits(0x04, count: 4)
        writer.writeBitsU32(0x1234, count: 16)
        #expect(writer.data == Data([0xB4, 0x12, 0x34]))
    }

    @Test
    func emulationPreventionByteInserted() {
        let writer = NalUnitWriter()
        writer.writeBytes(Data([0x00, 0x00, 0x00]))
        #expect(writer.data == Data([0x00, 0x00, 0x03, 0x00]))
    }

    @Test(arguments: [UInt8(0x00), 0x01, 0x02, 0x03])
    func emulationPreventionByteInsertedBeforeLowValue(value: UInt8) {
        let writer = NalUnitWriter()
        writer.writeBytes(Data([0x00, 0x00, value]))
        #expect(writer.data == Data([0x00, 0x00, 0x03, value]))
    }

    @Test(arguments: [UInt8(0x04), 0x30, 0x80, 0xFF])
    func noEmulationPreventionByteBeforeHighValue(value: UInt8) {
        let writer = NalUnitWriter()
        writer.writeBytes(Data([0x00, 0x00, value]))
        #expect(writer.data == Data([0x00, 0x00, value]))
    }

    @Test
    func emulationPreventionByteRestartsZeroRun() {
        let writer = NalUnitWriter()
        writer.writeBytes(Data([0x00, 0x00, 0x00, 0x00]))
        #expect(writer.data == Data([0x00, 0x00, 0x03, 0x00, 0x00]))
    }

    @Test
    func noEmulationPreventionByteWhenDisabled() {
        let writer = NalUnitWriter(emulationPrevention: false)
        writer.writeBytes(Data([0x00, 0x00, 0x00, 0x01]))
        #expect(writer.data == Data([0x00, 0x00, 0x00, 0x01]))
    }

    @Test
    func emulationPreventionByteRoundTrip() throws {
        let writer = NalUnitWriter()
        writer.writeBytes(Data([0xAB, 0x00, 0x00, 0x01, 0x00, 0x00, 0x30]))
        #expect(writer.data == Data([0xAB, 0x00, 0x00, 0x03, 0x01, 0x00, 0x00, 0x30]))
        let reader = NalUnitReader(data: writer.data)
        #expect(try reader.readBits(count: 8) == 0xAB)
        #expect(try reader.readBitsU32(count: 24) == 0x000001)
        #expect(try reader.readBitsU32(count: 24) == 0x000030)
    }
}
