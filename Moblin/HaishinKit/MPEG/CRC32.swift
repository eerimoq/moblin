import Foundation

final class CRC32 {
    static let mpeg2 = CRC32(polynomial: 0x04C1_1DB7)

    let table: [UInt32]

    init(polynomial: UInt32) {
        var table = [UInt32](repeating: 0x0000_0000, count: 256)
        for i in 0 ..< table.count {
            var crc = UInt32(i) << 24
            for _ in 0 ..< 8 {
                crc = (crc << 1) ^ ((crc & 0x8000_0000) == 0x8000_0000 ? polynomial : 0)
            }
            table[i] = crc
        }
        self.table = table
    }

    func calculate(_ data: Data) -> UInt32 {
        calculate(data, seed: nil)
    }

    func calculate(_ data: Data, seed: UInt32?) -> UInt32 {
        var crc: UInt32 = seed ?? 0xFFFF_FFFF
        for i in 0 ..< data.count {
            crc = (crc << 8) ^ table[Int((crc >> 24) ^ (UInt32(data[i]) & 0xFF) & 0xFF)]
        }
        return crc
    }
}
