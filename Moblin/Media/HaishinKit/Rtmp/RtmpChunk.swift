import Foundation

enum RtmpChunkType: UInt8 {
    case zero = 0
    case one = 1
    case two = 2
    case three = 3

    func messageHeaderSize() -> Int {
        switch self {
        case .zero:
            return 11
        case .one:
            return 7
        case .two:
            return 3
        case .three:
            return 0
        }
    }

    func areBasicAndMessageHeadersAvailable(_ data: Data) -> Bool {
        return basicHeaderSize(data[0]) + messageHeaderSize() < data.count
    }

    func toBasicHeader(_ chunkStreamId: UInt16) -> Data {
        if chunkStreamId <= 63 {
            return Data([rawValue << 6 | UInt8(chunkStreamId)])
        }
        if chunkStreamId <= 319 {
            return Data([rawValue << 6 | 0b0000000, UInt8(chunkStreamId - 64)])
        }
        return Data([rawValue << 6 | 0b0000_0001] + (chunkStreamId - 64).bigEndian.data)
    }
}

private func basicAndMessageHeadersSize(chunkStreamId: UInt16, type: RtmpChunkType) -> Int {
    return basicHeaderSize(chunkStreamId: chunkStreamId) + type.messageHeaderSize()
}

private func basicHeaderSize(chunkStreamId: UInt16) -> Int {
    if chunkStreamId <= 63 {
        return 1
    }
    if chunkStreamId <= 319 {
        return 2
    }
    return 3
}

private func basicHeaderSize(_ byte: UInt8) -> Int {
    switch byte & 0b0011_1111 {
    case 0:
        return 2
    case 1:
        return 3
    default:
        return 1
    }
}

final class RtmpChunk {
    enum ChunkStreamId: UInt16 {
        case control = 0x02
        case command = 0x03
        case data = 0x08
    }

    static let defaultSize = 128
    private static let maxTimestamp: UInt32 = 0xFFFFFF
    private var size = 0
    let type: RtmpChunkType
    let chunkStreamId: UInt16
    private(set) var message: RtmpMessage
    private(set) var fragmented = false

    init(type: RtmpChunkType, chunkStreamId: UInt16, message: RtmpMessage) {
        self.type = type
        self.chunkStreamId = chunkStreamId
        self.message = message
    }

    init(message: RtmpMessage) {
        type = .zero
        chunkStreamId = RtmpChunk.ChunkStreamId.command.rawValue
        self.message = message
    }

    init?(data: Data, size: Int) {
        guard !data.isEmpty,
              let type = RtmpChunkType(rawValue: (data[0] & 0b1100_0000) >> 6),
              type.areBasicAndMessageHeadersAvailable(data),
              type == .zero || type == .one
        else {
            return nil
        }
        self.size = size
        self.type = type
        let reader = ByteReader(data: data)
        do {
            let chunkStreamId = try UInt16(reader.readUInt8() & 0b0011_1111)
            switch chunkStreamId {
            case 0:
                self.chunkStreamId = try UInt16(reader.readUInt8()) + 64
            case 1:
                self.chunkStreamId = try reader.readUInt16() + 64
            default:
                self.chunkStreamId = chunkStreamId
            }
            let timestamp = try reader.readUInt24()
            let length = try Int(reader.readUInt24())
            guard let messageType = try RtmpMessageType(rawValue: reader.readUInt8()) else {
                return nil
            }
            let message = RtmpMessage.create(type: messageType)
            message.timestamp = timestamp
            message.length = length
            if type == .zero {
                message.streamId = try reader.readUInt32Le()
            }
            if message.timestamp == RtmpChunk.maxTimestamp {
                message.timestamp = try reader.readUInt32()
            }
            let end = min(message.length + reader.position, data.count)
            fragmented = size + reader.position <= end
            message.encoded = data.subdata(in: reader.position ..< min(size + reader.position, end))
            self.message = message
        } catch {
            return nil
        }
    }

    func ready() -> Bool {
        return message.length == message.encoded.count
    }

    func encode() -> Data {
        let writer = ByteWriter()
        writer.writeBytes(type.toBasicHeader(chunkStreamId))
        if message.timestamp > RtmpChunk.maxTimestamp {
            writer.writeUInt24(0xFFFFFF)
        } else {
            writer.writeUInt24(message.timestamp)
        }
        writer.writeUInt24(UInt32(message.encoded.count))
        writer.writeUInt8(message.type.rawValue)
        if type == .zero {
            writer.writeUInt32Le(message.streamId)
        }
        if message.timestamp > RtmpChunk.maxTimestamp {
            writer.writeUInt32(message.timestamp)
        }
        return writer.data + message.encoded
    }

    func append(data: Data, maximumSize: Int) -> Int {
        fragmented = false
        var length = message.length - message.encoded.count
        if data.count < length {
            length = data.count
        }
        let chunkSize = maximumSize - (message.encoded.count % maximumSize)
        if chunkSize < length {
            length = chunkSize
        }
        if length > 0 {
            message.encoded.append(data[0 ..< length])
        }
        fragmented = message.encoded.count % maximumSize == 0
        return length
    }

    func append(data: Data, message: RtmpMessage?) -> Int {
        guard let message else {
            return 0
        }
        let buffer = ByteReader(data: data)
        buffer.position = basicHeaderSize(chunkStreamId: chunkStreamId)
        do {
            self.message = RtmpMessage.create(type: message.type)
            self.message.streamId = message.streamId
            self.message.timestamp = type == .two ? try buffer.readUInt24() : message.timestamp
            self.message.length = message.length
            self.message.encoded = try Data(buffer.readBytes(message.length))
        } catch {
            logger.info("rtmp: \(buffer)")
        }
        return basicAndMessageHeadersSize(chunkStreamId: chunkStreamId, type: type) + message.length
    }

    func split(maximumSize: Int) -> [Data] {
        let data = encode()
        message.length = data.count
        guard maximumSize < message.encoded.count else {
            return [data]
        }
        let startIndex = maximumSize + basicAndMessageHeadersSize(chunkStreamId: chunkStreamId,
                                                                  type: type)
        let header = RtmpChunkType.three.toBasicHeader(chunkStreamId)
        var chunks = [data.subdata(in: 0 ..< startIndex)]
        for index in stride(from: startIndex, to: data.count, by: maximumSize) {
            let endIndex = index.advanced(by: index + maximumSize < data.count ? maximumSize : data.count - index)
            chunks.append(header + data.subdata(in: index ..< endIndex))
        }
        return chunks
    }
}
