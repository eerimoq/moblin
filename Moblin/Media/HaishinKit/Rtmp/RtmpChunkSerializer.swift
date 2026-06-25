import Foundation

class RtmpChunkSerializer {
    func serialize(chunk: RtmpChunk, maximumChunkSize: Int) -> [Data] {
        guard let message = chunk.message else {
            return [chunk.encode()]
        }

        let payload = message.encoded
        let headerType3 = RtmpChunkType.three.toBasicHeader(chunk.chunkStreamId)

        let writer = ByteWriter()
        writer.writeBytes(chunk.type.toBasicHeader(chunk.chunkStreamId))

        if message.timestamp > 0xFFFFFF {
            writer.writeUInt24(0xFFFFFF)
        } else {
            writer.writeUInt24(message.timestamp)
        }
        writer.writeUInt24(UInt32(payload.count))
        writer.writeUInt8(message.type.rawValue)
        if chunk.type == .zero {
            writer.writeUInt32Le(message.streamId)
        }
        if message.timestamp > 0xFFFFFF {
            writer.writeUInt32(message.timestamp)
        }

        let firstHeader = writer.data

        // Calculate exact total size to prevent reallocation
        let chunkCount = payload.isEmpty ? 1 : Int(ceil(Double(payload.count) / Double(maximumChunkSize)))
        let totalSize = firstHeader.count + payload
            .count + (chunkCount > 1 ? (chunkCount - 1) * headerType3.count : 0)

        var buffer = Data(capacity: totalSize)
        var results: [Data] = []
        var offset = 0

        if payload.isEmpty {
            buffer.append(firstHeader)
            results.append(buffer)
            return results
        }

        while offset < payload.count {
            let chunkSize = min(maximumChunkSize, payload.count - offset)
            let isFirst = offset == 0

            let header = isFirst ? firstHeader : headerType3

            let startIdx = buffer.count
            buffer.append(header)
            // Use subdata bounds to prevent inline copying overhead
            let payloadSlice = payload.subdata(in: offset ..< offset + chunkSize)
            buffer.append(payloadSlice)
            let endIdx = buffer.count

            // subdata creates a shared view into the contiguous buffer, zero-copy at Swift level
            results.append(buffer.subdata(in: startIdx ..< endIdx))

            offset += chunkSize
        }
        return results
    }
}
