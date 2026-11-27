import Foundation

class ByteWriter {
    private(set) var data = Data()
    private var position = 0

    init() {}

    init(data: Data) {
        self.data = data
    }

    func writeUInt8(_ value: UInt8) {
        if position == data.count {
            data.append(value)
            position += 1
        } else {
            writeBytes(value.data)
        }
    }

    func writeUInt16(_ value: UInt16) {
        writeUInt8(UInt8((value >> 8) & 0xFF))
        writeUInt8(UInt8(value & 0xFF))
    }

    func writeUInt16Le(_ value: UInt16) {
        writeUInt8(UInt8(value & 0xFF))
        writeUInt8(UInt8((value >> 8) & 0xFF))
    }

    func writeUInt24(_ value: UInt32) {
        writeUInt8(UInt8((value >> 16) & 0xFF))
        writeUInt8(UInt8((value >> 8) & 0xFF))
        writeUInt8(UInt8(value & 0xFF))
    }

    func writeUInt24Le(_ value: UInt32) {
        writeUInt8(UInt8(value & 0xFF))
        writeUInt8(UInt8((value >> 8) & 0xFF))
        writeUInt8(UInt8((value >> 16) & 0xFF))
    }

    func writeUInt32(_ value: UInt32) {
        writeUInt8(UInt8((value >> 24) & 0xFF))
        writeUInt8(UInt8((value >> 16) & 0xFF))
        writeUInt8(UInt8((value >> 8) & 0xFF))
        writeUInt8(UInt8(value & 0xFF))
    }

    func writeUInt32Le(_ value: UInt32) {
        writeUInt8(UInt8(value & 0xFF))
        writeUInt8(UInt8((value >> 8) & 0xFF))
        writeUInt8(UInt8((value >> 16) & 0xFF))
        writeUInt8(UInt8((value >> 24) & 0xFF))
    }

    func writeUInt64(_ value: UInt64) {
        writeUInt32(UInt32((value >> 32) & 0xFFFF_FFFF))
        writeUInt32(UInt32(value & 0xFFFF_FFFF))
    }

    func writeInt32(_ value: Int32) {
        writeBytes(value.bigEndian.data)
    }

    func writeDouble(_ value: Double) {
        writeBytes(Data(value.data.reversed()))
    }

    func writeUTF8Bytes(_ value: String) {
        writeBytes(Data(value.utf8))
    }

    func writeBytes(_ value: Data) {
        if position == data.count {
            data.append(value)
            position = data.count
        } else {
            let length = min(data.count, value.count)
            data[position ..< position + length] = value[0 ..< length]
            if length == data.count {
                data.append(value[length ..< value.count])
            }
            position += value.count
        }
    }

    func writeBytes(_ value: UnsafeRawBufferPointer) {
        if position == data.count {
            data.append(value.baseAddress!.assumingMemoryBound(to: UInt8.self), count: value.count)
            position = data.count
        } else {
            writeBytes(Data(value))
        }
    }
}
