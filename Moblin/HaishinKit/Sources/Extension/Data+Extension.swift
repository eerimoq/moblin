import CoreMedia
import Foundation

extension Data {
    var bytes: [UInt8] {
        withUnsafeBytes {
            guard let pointer = $0.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return []
            }
            return [UInt8](UnsafeBufferPointer(start: pointer, count: count))
        }
    }

    func chunks(_ size: Int) -> [Data] {
        if count < size {
            return [self]
        }
        var chunks: [Data] = []
        let length = count
        var offset = 0
        repeat {
            let thisChunkSize = ((length - offset) > size) ? size : (length - offset)
            chunks.append(subdata(in: offset ..< offset + thisChunkSize))
            offset += thisChunkSize
        } while offset < length
        return chunks
    }
}
