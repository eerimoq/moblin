import Foundation
@testable import Moblin
import Testing

struct NalUnitReaderSuite {
    @Test
    func readBitMsbFirst() throws {
        let reader = NalUnitReader(data: Data([0xA5]))
        #expect(try reader.readBit() == true)
        #expect(try reader.readBit() == false)
        #expect(try reader.readBit() == true)
        #expect(try reader.readBit() == false)
        #expect(try reader.readBit() == false)
        #expect(try reader.readBit() == true)
        #expect(try reader.readBit() == false)
        #expect(try reader.readBit() == true)
    }

    @Test
    func readBitsHighAndLowNibble() throws {
        let reader = NalUnitReader(data: Data([0xB4]))
        #expect(try reader.readBits(count: 4) == 0x0B)
        #expect(try reader.readBits(count: 4) == 0x04)
    }

    @Test
    func readBitsFullByte() throws {
        let reader = NalUnitReader(data: Data([0xFF]))
        #expect(try reader.readBits(count: 8) == 0xFF)
    }

    @Test
    func readBitsU32AcrossTwoBytes() throws {
        let reader = NalUnitReader(data: Data([0x12, 0x34]))
        #expect(try reader.readBitsU32(count: 16) == 0x1234)
    }

    @Test
    func readBitsU32AcrossThreeBytes() throws {
        let reader = NalUnitReader(data: Data([0xAB, 0xCD, 0xEF]))
        #expect(try reader.readBitsU32(count: 24) == 0xABCDEF)
    }

    @Test
    func skipBitsAdvancesPosition() throws {
        let reader = NalUnitReader(data: Data([0x00, 0xBE]))
        try reader.skipBits(count: 8)
        #expect(try reader.readBits(count: 8) == 0xBE)
    }

    @Test
    func availableDecrementsAfterReads() throws {
        let reader = NalUnitReader(data: Data([0xAA, 0xBB]))
        #expect(reader.available() == 16)
        _ = try reader.readBit()
        #expect(reader.available() == 15)
        try reader.skipBits(count: 7)
        #expect(reader.available() == 8)
        _ = try reader.readBits(count: 8)
        #expect(reader.available() == 0)
    }

    @Test
    func emulationPreventionByteIsSkipped() throws {
        let reader = NalUnitReader(data: Data([0x00, 0x00, 0x03, 0x80]))
        #expect(try reader.readBitsU32(count: 24) == 0x000080)
    }

    @Test
    func noFalseEmulationPreventionByteRemoval() throws {
        let reader = NalUnitReader(data: Data([0x01, 0x00, 0x03, 0x80]))
        #expect(try reader.readBitsU32(count: 32) == 0x0100_0380)
    }

    @Test
    func readRawBytesReturnsRemainingData() throws {
        let reader = NalUnitReader(data: Data([0x12, 0x34, 0x56]))
        _ = try reader.readBits(count: 8)
        let remaining = try reader.readRawBytes()
        #expect(remaining == Data([0x34, 0x56]))
    }

    @Test
    func readRawBytesAtStart() throws {
        let data = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let reader = NalUnitReader(data: data)
        #expect(try reader.readRawBytes() == data)
    }

    @Test
    func readRawBytesThrowsWhenNotOnByteBoundary() throws {
        let reader = NalUnitReader(data: Data([0xFF, 0x00]))
        _ = try reader.readBit()
        #expect(throws: (any Error).self) {
            try reader.readRawBytes()
        }
    }

    @Test
    func readBitThrowsOnEmptyData() {
        let reader = NalUnitReader(data: Data())
        #expect(throws: (any Error).self) {
            try reader.readBit()
        }
    }

    @Test
    func readBitThrowsAfterAllBitsConsumed() throws {
        let reader = NalUnitReader(data: Data([0xFF]))
        try reader.skipBits(count: 8)
        #expect(throws: (any Error).self) {
            try reader.readBit()
        }
    }

    @Test
    func offsetSkipsInitialBytes() throws {
        let reader = NalUnitReader(data: Data([0x12, 0x34, 0x56]), offset: 1)
        #expect(try reader.readBits(count: 8) == 0x34)
        #expect(try reader.readBits(count: 8) == 0x56)
    }
}
