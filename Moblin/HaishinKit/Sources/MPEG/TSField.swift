import Foundation

class TSAdaptationField {
    static let fixedSectionSize: UInt8 = 2

    var length: UInt8 = 0
    var randomAccessIndicator = false
    var pcr: Data?
    var stuffingBytes: Data?

    init() {}

    init(data: Data) {
        self.data = data
    }

    func compute() {
        length = TSAdaptationField.fixedSectionSize
        if let pcr {
            length += UInt8(truncatingIfNeeded: pcr.count)
        }
        if let stuffingBytes {
            length += UInt8(truncatingIfNeeded: stuffingBytes.count)
        }
        length -= 1
    }

    func stuffing(_ size: Int) {
        stuffingBytes = Data(repeating: 0xFF, count: size)
        length += UInt8(size)
    }

    var data: Data {
        get {
            var byte: UInt8 = 0
            byte |= randomAccessIndicator ? 0x40 : 0
            byte |= pcr != nil ? 0x10 : 0
            let buffer = ByteArray()
                .writeUInt8(length)
                .writeUInt8(byte)
            if let pcr {
                buffer.writeBytes(pcr)
            }
            if let stuffingBytes {
                buffer.writeBytes(stuffingBytes)
            }
            return buffer.data
        }
        set {
            let buffer = ByteArray(data: newValue)
            do {
                length = try buffer.readUInt8()
                let byte = try buffer.readUInt8()
                randomAccessIndicator = (byte & 0x40) == 0x40
                stuffingBytes = try buffer.readBytes(buffer.bytesAvailable)
            } catch {
                logger.error("\(buffer)")
            }
        }
    }
}
