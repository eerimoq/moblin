import Foundation

final class BitReader {
    private var data: Data
    private var byteOffset = 0
    private var bitOffset = 7

    init(data: Data) {
        self.data = data
    }

    func readBit() throws -> Bool {
        try checkOutOfData()
        let value = data[byteOffset].isBitSet(index: bitOffset)
        bitOffset -= 1
        if bitOffset == -1 {
            bitOffset = 7
            byteOffset += 1
        }
        return value
    }

    func skipBits(count: Int) throws {
        bitOffset -= count % 8
        if bitOffset < 0 {
            bitOffset += 8
            byteOffset += 1
        }
        byteOffset += count / 8
        try checkOutOfData()
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

    private func checkOutOfData() throws {
        if byteOffset >= data.count {
            throw "Out of data"
        }
    }
}
