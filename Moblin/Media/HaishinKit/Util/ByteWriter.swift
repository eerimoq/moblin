import Foundation

class ByteWriter {
    private(set) var data = Data()
    private var position = 0

    var length: Int {
        get {
            data.count
        }
        set {
            if newValue > data.count {
                data.append(Data(count: newValue - data.count))
            } else if newValue < data.count {
                data = data.subdata(in: 0 ..< newValue)
            }
        }
    }

    init() {}

    init(data: Data) {
        self.data = data
    }

    subscript(i: Int) -> UInt8 {
        get {
            data[i]
        }
        set {
            data[i] = newValue
        }
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

    func sequence(_ length: Int, lambda: (ByteWriter) -> Void) {
        let r = (data.count - position) % length
        for index in stride(
            from: data.startIndex.advanced(by: position),
            to: data.endIndex.advanced(by: -r),
            by: length
        ) {
            lambda(ByteWriter(data: data.subdata(in: index ..< index.advanced(by: length))))
        }
        if r > 0 {
            lambda(ByteWriter(data: data.advanced(by: data.endIndex - r)))
        }
    }

    func toUInt32() -> [UInt32] {
        let size = MemoryLayout<UInt32>.size
        if (data.endIndex - position) % size != 0 {
            return []
        }
        var result: [UInt32] = []
        for index in stride(from: data.startIndex.advanced(by: position), to: data.endIndex, by: size) {
            result.append(UInt32(data: data[index ..< index.advanced(by: size)]))
        }
        return result
    }
}
