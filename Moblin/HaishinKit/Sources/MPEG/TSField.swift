import Foundation

class TSAdaptationField {
    static let fixedSectionSize: UInt8 = 2
    var randomAccessIndicator = false
    var pcr: Data?
    var stuffingBytes: Data?

    init() {}

    func calcLength() -> UInt8 {
        var length = TSAdaptationField.fixedSectionSize
        if let pcr {
            length += UInt8(truncatingIfNeeded: pcr.count)
        }
        if let stuffingBytes {
            length += UInt8(truncatingIfNeeded: stuffingBytes.count)
        }
        return length
    }

    func setStuffing(_ size: Int) {
        stuffingBytes = Data(repeating: 0xFF, count: size)
    }

    func encode() -> Data {
        var flags: UInt8 = 0
        if randomAccessIndicator {
            flags |= 0x40
        }
        if pcr != nil {
            flags |= 0x10
        }
        let buffer = ByteArray()
            .writeUInt8(calcLength() - 1)
            .writeUInt8(flags)
        if let pcr {
            buffer.writeBytes(pcr)
        }
        if let stuffingBytes {
            buffer.writeBytes(stuffingBytes)
        }
        return buffer.data
    }
}
