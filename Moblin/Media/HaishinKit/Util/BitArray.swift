import Foundation

open class BitArray {
    private(set) var data = Data()
    private(set) var bitOffset = 0

    init() {}

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
}
