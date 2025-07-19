import Foundation

struct MpegTsAdaptationField {
    static let fixedSectionSize: UInt8 = 2
    var randomAccessIndicator = false
    var programClockReference: Data?
    var stuffingBytes: Data?

    init() {}

    init(reader: ByteReader, length: UInt8) throws {
        let startPosition = reader.position
        let byte = try reader.readUInt8()
        randomAccessIndicator = (byte & 0x40) == 0x40
        let hasProgramClockReference = (byte & 0x10) == 0x10
        if hasProgramClockReference {
            programClockReference = try reader.readBytes(6)
        }
        let stuffingCount = (startPosition + Int(length)) - reader.position
        if stuffingCount > 0 {
            _ = try reader.readBytes(stuffingCount)
        }
    }

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

    mutating func setStuffing(_ size: Int) {
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
        let writer = ByteWriter()
        writer.writeUInt8(calcLength() - 1)
        writer.writeUInt8(flags)
        if let programClockReference {
            writer.writeBytes(programClockReference)
        }
        if let stuffingBytes {
            writer.writeBytes(stuffingBytes)
        }
        return writer.data
    }
}
