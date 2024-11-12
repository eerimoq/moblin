import Foundation

let nalUnitStartCode = Data([0x00, 0x00, 0x00, 0x01])

struct AvcFormatStream {
    private let data: Data

    init(bytes: UnsafePointer<UInt8>, count: Int) {
        data = Data(bytes: bytes, count: count)
    }

    func toByteStream() -> Data {
        let buffer = ByteArray(data: data)
        var result = Data()
        while buffer.bytesAvailable > 0 {
            do {
                let length = try Int(buffer.readUInt32())
                result += nalUnitStartCode
                try result.append(buffer.readBytes(length))
            } catch {
                logger.error("\(buffer)")
            }
        }
        return result
    }
}
