import Foundation

private let extendedTimestampMarker: UInt32 = 0xFFFFFF

enum RtmpChunkType: UInt8 {
    case zero = 0
    case one = 1
    case two = 2
    case three = 3

    func messageHeaderSize() -> Int {
        switch self {
        case .zero:
            11
        case .one:
            7
        case .two:
            3
        case .three:
            0
        }
    }

    func toBasicHeader(_ chunkStreamId: UInt16) -> Data {
        if chunkStreamId <= 63 {
            return Data([rawValue << 6 | UInt8(chunkStreamId)])
        }
        if chunkStreamId <= 319 {
            return Data([rawValue << 6 | 0b0000000, UInt8(chunkStreamId - 64)])
        }
        return Data([rawValue << 6 | 0b0000_0001] + (chunkStreamId - 64).littleEndian.data)
    }
}

private func basicAndMessageHeadersSize(chunkStreamId: UInt16,
                                        type: RtmpChunkType,
                                        hasExtendedTimestamp: Bool) -> Int
{
    basicHeaderSize(chunkStreamId: chunkStreamId) + type.messageHeaderSize()
        + (hasExtendedTimestamp ? 4 : 0)
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

final class RtmpChunk {
    enum ChunkStreamId: UInt16 {
        case control = 0x02
        case command = 0x03
        case data = 0x04
    }

    static let defaultSize = 128
    private let type: RtmpChunkType
    private let chunkStreamId: UInt16
    let message: RtmpMessage

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

    private var hasExtendedTimestamp: Bool {
        message.timestamp >= extendedTimestampMarker
    }

    func encode() -> Data {
        let writer = ByteWriter()
        writer.writeBytes(type.toBasicHeader(chunkStreamId))
        if hasExtendedTimestamp {
            writer.writeUInt24(extendedTimestampMarker)
        } else {
            writer.writeUInt24(message.timestamp)
        }
        writer.writeUInt24(UInt32(message.encoded.count))
        writer.writeUInt8(message.type.rawValue)
        if type == .zero {
            writer.writeUInt32Le(message.streamId)
        }
        if hasExtendedTimestamp {
            writer.writeUInt32(message.timestamp)
        }
        return writer.data + message.encoded
    }

    func split(maximumSize: Int) -> [Data] {
        let data = encode()
        message.length = data.count
        guard maximumSize < message.encoded.count else {
            return [data]
        }
        let startIndex = maximumSize + basicAndMessageHeadersSize(
            chunkStreamId: chunkStreamId,
            type: type,
            hasExtendedTimestamp: hasExtendedTimestamp
        )
        var header = RtmpChunkType.three.toBasicHeader(chunkStreamId)
        if hasExtendedTimestamp {
            header += message.timestamp.bigEndian.data
        }
        var chunks = [data.subdata(in: 0 ..< startIndex)]
        for index in stride(from: startIndex, to: data.count, by: maximumSize) {
            let endIndex = index
                .advanced(by: index + maximumSize < data.count ? maximumSize : data.count - index)
            chunks.append(header + data.subdata(in: index ..< endIndex))
        }
        return chunks
    }
}

private struct RtmpBasicHeader {
    let type: RtmpChunkType
    let chunkStreamId: UInt16
}

private struct RtmpChunkStream {
    var timestamp: UInt32 = 0
    var timestampDelta: UInt32 = 0
    var messageType: RtmpMessageType?
    var messageLength = 0
    var messageStreamId: UInt32 = 0
    var hasExtendedTimestamp = false
    var payload = Data()
}

private extension ByteReader {
    func canRead(_ count: Int) -> Bool {
        bytesAvailable >= count
    }
}

final class RtmpChunkReader {
    var maximumChunkSize = RtmpChunk.defaultSize
    private var chunkStreams: [UInt16: RtmpChunkStream] = [:]

    func clear() {
        maximumChunkSize = RtmpChunk.defaultSize
        chunkStreams.removeAll()
    }

    func read(data: Data, onMessage: (RtmpMessage) -> Void) -> Data {
        var offset = 0
        while let size = readChunk(data: data, offset: offset, onMessage: onMessage) {
            offset += size
        }
        guard offset > 0 else {
            return data
        }
        return data.subdata(in: offset ..< data.count)
    }

    private func readChunk(data: Data, offset: Int, onMessage: (RtmpMessage) -> Void) -> Int? {
        let reader = ByteReader(data: data)
        reader.position = offset
        guard let basicHeader = readBasicHeader(reader: reader) else {
            return nil
        }
        var chunkStream = chunkStreams[basicHeader.chunkStreamId] ?? RtmpChunkStream()
        guard readMessageHeader(reader: reader, type: basicHeader.type, chunkStream: &chunkStream) else {
            return nil
        }
        let payloadSize = min(chunkStream.messageLength - chunkStream.payload.count, maximumChunkSize)
        guard reader.canRead(payloadSize) else {
            return nil
        }
        chunkStream.payload += try! reader.readBytes(payloadSize)
        if chunkStream.payload.count == chunkStream.messageLength {
            if let message = makeMessage(chunkStream: chunkStream) {
                onMessage(message)
            }
            chunkStream.payload = Data()
        }
        chunkStreams[basicHeader.chunkStreamId] = chunkStream
        return reader.position - offset
    }

    private func readBasicHeader(reader: ByteReader) -> RtmpBasicHeader? {
        guard reader.canRead(1) else {
            return nil
        }
        let firstByte = try! reader.readUInt8()
        guard let type = RtmpChunkType(rawValue: firstByte >> 6) else {
            return nil
        }
        switch firstByte & 0b0011_1111 {
        case 0:
            guard reader.canRead(1) else {
                return nil
            }
            return RtmpBasicHeader(type: type, chunkStreamId: UInt16(try! reader.readUInt8()) + 64)
        case 1:
            guard reader.canRead(2) else {
                return nil
            }
            return RtmpBasicHeader(type: type, chunkStreamId: (try! reader.readUInt16Le()) &+ 64)
        case let chunkStreamId:
            return RtmpBasicHeader(type: type, chunkStreamId: UInt16(chunkStreamId))
        }
    }

    private func readMessageHeader(reader: ByteReader,
                                   type: RtmpChunkType,
                                   chunkStream: inout RtmpChunkStream) -> Bool
    {
        guard reader.canRead(type.messageHeaderSize()) else {
            return false
        }
        var timestamp = chunkStream.timestampDelta
        switch type {
        case .zero:
            timestamp = try! reader.readUInt24()
            chunkStream.messageLength = Int(try! reader.readUInt24())
            chunkStream.messageType = RtmpMessageType(rawValue: try! reader.readUInt8())
            chunkStream.messageStreamId = try! reader.readUInt32Le()
        case .one:
            timestamp = try! reader.readUInt24()
            chunkStream.messageLength = Int(try! reader.readUInt24())
            chunkStream.messageType = RtmpMessageType(rawValue: try! reader.readUInt8())
        case .two:
            timestamp = try! reader.readUInt24()
        case .three:
            break
        }
        if type != .three {
            chunkStream.hasExtendedTimestamp = timestamp == extendedTimestampMarker
        }
        if chunkStream.hasExtendedTimestamp {
            guard reader.canRead(4) else {
                return false
            }
            timestamp = try! reader.readUInt32()
        }
        let isFirstChunkOfMessage = type != .three || chunkStream.payload.isEmpty
        if isFirstChunkOfMessage {
            chunkStream.payload = Data()
            if type == .zero {
                chunkStream.timestamp = timestamp
            } else {
                chunkStream.timestamp &+= timestamp
            }
        }
        chunkStream.timestampDelta = type == .zero ? 0 : timestamp
        return true
    }

    private func makeMessage(chunkStream: RtmpChunkStream) -> RtmpMessage? {
        guard let messageType = chunkStream.messageType else {
            return nil
        }
        let message = RtmpMessage.create(type: messageType)
        message.timestamp = chunkStream.timestamp
        message.length = chunkStream.messageLength
        message.streamId = chunkStream.messageStreamId
        message.encoded = chunkStream.payload
        return message
    }
}
