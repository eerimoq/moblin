import Foundation

enum RTMPChunkType: UInt8 {
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
        return RTMPChunk.basicHeaderSize(data[0]) + messageHeaderSize() < data.count
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

final class RTMPChunk {
    enum ChunkStreamId: UInt16 {
        case control = 0x02
        case command = 0x03
        // case audio = 0x04
        // case video = 0x05
        case data = 0x08
    }

    static let defaultSize = 128
    static let maxTimestamp: UInt32 = 0xFFFFFF

    static func basicHeaderSize(_ byte: UInt8) -> Int {
        switch byte & 0b0011_1111 {
        case 0:
            return 2
        case 1:
            return 3
        default:
            return 1
        }
    }

    var size = 0
    var type: RTMPChunkType = .zero
    var chunkStreamId = RTMPChunk.ChunkStreamId.command.rawValue

    func ready() -> Bool {
        guard let message else {
            return false
        }
        return message.length == message.payload.count
    }

    private func basicAndMessageHeadersSize() -> Int {
        if chunkStreamId <= 63 {
            return 1 + type.messageHeaderSize()
        }
        if chunkStreamId <= 319 {
            return 2 + type.messageHeaderSize()
        }
        return 3 + type.messageHeaderSize()
    }

    private func basicHeaderSize() -> Int {
        if chunkStreamId <= 63 {
            return 1
        }
        if chunkStreamId <= 319 {
            return 2
        }
        return 3
    }

    private(set) var message: RTMPMessage?
    private(set) var fragmented = false
    private var header = Data()

    init(type: RTMPChunkType, chunkStreamId: UInt16, message: RTMPMessage) {
        self.type = type
        self.chunkStreamId = chunkStreamId
        self.message = message
    }

    init(message: RTMPMessage) {
        self.message = message
    }

    init?(_ data: Data, size: Int) {
        if data.isEmpty {
            return nil
        }
        guard let type = RTMPChunkType(rawValue: (data[0] & 0b1100_0000) >> 6) else {
            return nil
        }
        guard type.areBasicAndMessageHeadersAvailable(data) else {
            return nil
        }
        self.size = size
        self.type = type
        decode(data: data)
    }

    func encode() -> Data {
        guard let message else {
            return header
        }
        guard header.isEmpty else {
            return header + message.payload
        }
        header.append(type.toBasicHeader(chunkStreamId))
        if RTMPChunk.maxTimestamp < message.timestamp {
            header.append(contentsOf: [0xFF, 0xFF, 0xFF])
        } else {
            header.append(contentsOf: message.timestamp.bigEndian.data[1 ... 3])
        }
        header.append(contentsOf: UInt32(message.payload.count).bigEndian.data[1 ... 3])
        header.append(message.type.rawValue)
        if type == .zero {
            header.append(message.streamId.littleEndian.data)
        }
        if RTMPChunk.maxTimestamp < message.timestamp {
            header.append(message.timestamp.bigEndian.data)
        }
        return header + message.payload
    }

    private func decode(data: Data) {
        var pos = 0
        switch data[0] & 0b0011_1111 {
        case 0:
            pos = 2
            chunkStreamId = UInt16(data[1]) + 64
        case 1:
            pos = 3
            chunkStreamId = UInt16(data: data[1 ... 2]) + 64
        default:
            pos = 1
            chunkStreamId = UInt16(data[0] & 0b0011_1111)
        }
        if type == .two || type == .three {
            return
        }
        guard let messageType = RTMPMessageType(rawValue: data[pos + 6]) else {
            logger.error(data.description)
            return
        }
        let message = RTMPMessage.create(type: messageType)
        switch type {
        case .zero:
            message.timestamp = UInt32(data: data[pos ..< pos + 3]).bigEndian
            message.length = Int(Int32(data: data[pos + 3 ..< pos + 6]).bigEndian)
            message.streamId = UInt32(data: data[pos + 7 ..< pos + 11])
        case .one:
            message.timestamp = UInt32(data: data[pos ..< pos + 3]).bigEndian
            message.length = Int(Int32(data: data[pos + 3 ..< pos + 6]).bigEndian)
        default:
            break
        }
        var start = basicAndMessageHeadersSize()
        if message.timestamp == RTMPChunk.maxTimestamp {
            message.timestamp = UInt32(data: data[start ..< start + 4]).bigEndian
            start += 4
        }
        let end = min(message.length + start, data.count)
        fragmented = size + start <= end
        message.payload = data.subdata(in: start ..< min(size + start, end))
        self.message = message
    }

    func append(_ data: Data, size: Int) -> Int {
        fragmented = false
        guard let message else {
            return 0
        }
        var length = message.length - message.payload.count
        if data.count < length {
            length = data.count
        }
        let chunkSize = size - (message.payload.count % size)
        if chunkSize < length {
            length = chunkSize
        }
        if length > 0 {
            message.payload.append(data[0 ..< length])
        }
        fragmented = message.payload.count % size == 0
        return length
    }

    func append(_ data: Data, message: RTMPMessage?) -> Int {
        guard let message else {
            return 0
        }
        let buffer = ByteArray(data: data)
        buffer.position = basicHeaderSize()
        do {
            self.message = RTMPMessage.create(type: message.type)
            self.message?.streamId = message.streamId
            self.message?.timestamp = type == .two ? try buffer.readUInt24() : message.timestamp
            self.message?.length = message.length
            self.message?.payload = try Data(buffer.readBytes(message.length))
        } catch {
            logger.info("\(buffer)")
        }
        return basicAndMessageHeadersSize() + message.length
    }

    func split(_ size: Int) -> [Data] {
        let data = encode()
        message?.length = data.count
        guard let message, size < message.payload.count else {
            return [data]
        }
        let startIndex = size + basicAndMessageHeadersSize()
        let header = RTMPChunkType.three.toBasicHeader(chunkStreamId)
        var chunks = [data.subdata(in: 0 ..< startIndex)]
        for index in stride(from: startIndex, to: data.count, by: size) {
            var chunk = header
            chunk
                .append(data
                    .subdata(in: index ..< index.advanced(by: index + size < data.count ? size : data.count - index)))
            chunks.append(chunk)
        }
        return chunks
    }
}
