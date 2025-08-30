import Foundation

final class NalUnitReader {
    private var data: Data
    private var byteOffset = 0
    private var bitOffset = 7

    init(data: Data, offset: Int = 0) {
        self.data = data
        byteOffset = offset
    }

    func isByteAligned() -> Bool {
        return bitOffset == 7
    }

    func available() -> Int {
        return 8 * (data.count - byteOffset) - (7 - bitOffset)
    }

    func readRawBytes() throws -> Data {
        try checkOutOfData()
        guard bitOffset == 7 else {
            throw "Cannot read remaining bytes when not at byte boundary"
        }
        return data.advanced(by: byteOffset)
    }

    func readBit() throws -> Bool {
        try checkOutOfData()
        let value = data[byteOffset].isBitSet(index: bitOffset)
        bitOffset -= 1
        if bitOffset == -1 {
            bitOffset = 7
            byteOffset += 1
            if available() > 0,
               byteOffset >= 2,
               data[byteOffset - 2] == 0,
               data[byteOffset - 1] == 0,
               data[byteOffset] == nalUnitEmulationPreventionByte
            {
                byteOffset += 1
            }
        }
        return value
    }

    func skipBits(count: Int) throws {
        for _ in 0 ..< count {
            _ = try readBit()
        }
    }

    func readBits(count: Int) throws -> UInt8 {
        var value: UInt8 = 0
        for _ in 0 ..< count {
            value <<= 1
            value |= try readBit() ? 1 : 0
        }
        return value
    }

    func readBitsU32(count: Int) throws -> UInt32 {
        var value: UInt32 = 0
        for _ in 0 ..< count {
            value <<= 1
            value |= try readBit() ? 1 : 0
        }
        return value
    }

    func readExponentialGolomb() throws -> UInt32 {
        var numberOfLeadingZeroBits = 0
        while true {
            let bit = try readBit()
            if bit {
                break
            }
            numberOfLeadingZeroBits += 1
        }
        var value: UInt32 = 1 << numberOfLeadingZeroBits
        value |= try readBitsU32(count: numberOfLeadingZeroBits)
        return value - 1
    }

    func skipExponentialGolomb() throws {
        _ = try readExponentialGolomb()
    }

    private func checkOutOfData() throws {
        if byteOffset >= data.count {
            throw "Out of data"
        }
    }
}
