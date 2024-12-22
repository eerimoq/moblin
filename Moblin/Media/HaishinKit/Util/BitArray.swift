import Foundation

open class BitArray {
    private(set) var data = Data()
    private(set) var byteOffset = 0
    private(set) var bitOffset = 0

    init() {}

    init(data: Data) {
        self.data = data
    }

    func writeBit(_ value: Bool) {
        if bitOffset == 0 {
            data.append(0)
        }
        if value {
            data[data.count - 1] |= (1 << (7 - bitOffset))
        }
        bitOffset += 1
        bitOffset %= 8
    }

    func readBit() throws -> Bool {
        guard byteOffset < data.count else {
            throw "Out of data"
        }
        let mask = UInt8(1 << (7 - bitOffset))
        let value = (data[byteOffset] & mask) == mask
        bitOffset += 1
        if bitOffset == 8 {
            bitOffset = 0
            byteOffset += 1
        }
        return value
    }

    func writeBits(_ value: UInt8, count: Int) {
        for i in 0 ..< count {
            let mask = UInt8(1 << (count - i - 1))
            writeBit((value & mask) == mask)
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

    func writeBitsU32(_ value: UInt32, count: Int) {
        for i in 0 ..< count {
            let mask = UInt32(1 << (count - i - 1))
            writeBit((value & mask) == mask)
        }
    }

    func readBitsU32(count: Int) throws -> UInt32 {
        var value: UInt32 = 0
        for _ in 0 ..< count {
            value <<= 1
            value |= try readBit() ? 1 : 0
        }
        return value
    }

    func writeBytes(_ data: Data) {
        for value in data {
            writeBits(value, count: 8)
        }
    }
}
