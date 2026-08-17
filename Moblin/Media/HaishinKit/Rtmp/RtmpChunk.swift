import Foundation

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
    private static let extendedTimestampMarker: UInt32 = 0xFFFFFF
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
        message.timestamp >= RtmpChunk.extendedTimestampMarker
    }

    func encode() -> Data {
        let writer = ByteWriter()
        writer.writeBytes(type.toBasicHeader(chunkStreamId))
        if hasExtendedTimestamp {
            writer.writeUInt24(RtmpChunk.extendedTimestampMarker)
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
