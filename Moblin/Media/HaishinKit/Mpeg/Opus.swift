import Foundation

enum OpusHeader {
    static func encode(length: Int) -> Data {
        var header = Data(count: 2)
        header.withUnsafeMutableBytes { pointer in
            pointer.writeUInt16(0x3FF << 5, offset: 0)
        }
        var length = length
        while length >= 0 {
            header.append(length < 255 ? UInt8(length) : 255)
            length -= 255
        }
        return header
    }

    static func decode(data: Data) -> (Int, Int)? {
        let reader = ByteReader(data: data)
        var length = 0
        do {
            _ = try reader.readUInt16()
            while true {
                let value = try reader.readUInt8()
                length += Int(value)
                if value < 255 {
                    return (length, reader.position)
                }
            }
        } catch {
            return nil
        }
    }
}
