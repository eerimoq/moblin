import Foundation

class MpegTsAdaptationField {
    static let fixedSectionSize: UInt8 = 2
    var randomAccessIndicator = false
    var programClockReference: Data?
    var stuffingBytes: Data?

    init() {}

    func calcLength() -> UInt8 {
        var length = MpegTsAdaptationField.fixedSectionSize
        if let programClockReference {
            length += UInt8(truncatingIfNeeded: programClockReference.count)
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
        if programClockReference != nil {
            flags |= 0x10
        }
        let encoded = ByteArray()
            .writeUInt8(calcLength() - 1)
            .writeUInt8(flags)
        if let programClockReference {
            encoded.writeBytes(programClockReference)
        }
        if let stuffingBytes {
            encoded.writeBytes(stuffingBytes)
        }
        return encoded.data
    }
}
