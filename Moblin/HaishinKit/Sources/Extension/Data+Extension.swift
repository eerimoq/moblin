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

    func replaceBlockBuffer(blockBuffer: CMBlockBuffer) {
        withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            guard let baseAddress = buffer.baseAddress else {
                return
            }
            guard CMBlockBufferReplaceDataBytes(
                with: baseAddress,
                blockBuffer: blockBuffer,
                offsetIntoDestination: 0,
                dataLength: count
            ) == noErr else {
                return
            }
        }
    }

    func getInt16(offset: Int = 0) -> Int16 {
        return withUnsafeBytes { data in
            data.load(fromByteOffset: offset, as: Int16.self)
        }
    }

    mutating func setInt16(value: Int16, offset: Int = 0) {
        withUnsafeMutableBytes { data in data.storeBytes(
            of: value,
            toByteOffset: offset,
            as: Int16.self
        ) }
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
