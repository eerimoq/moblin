import Foundation

final class BitWriter {
    private(set) var data: Data
    private var byteOffset = 0
    private(set) var bitOffset = 0

    init() {
        data = Data()
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

    func writeBits(_ value: UInt8, count: Int) {
        for i in 0 ..< count {
            let mask = UInt8(1 << (count - i - 1))
            writeBit((value & mask) == mask)
        }
    }

    func writeBitsU32(_ value: UInt32, count: Int) {
        for i in 0 ..< count {
            let mask = UInt32(1 << (count - i - 1))
            writeBit((value & mask) == mask)
        }
    }

    func writeBytes(_ data: Data) {
        for value in data {
            writeBits(value, count: 8)
        }
    }
}
