import CoreMedia
import Foundation

extension CMBlockBuffer {
    var data: Data? {
        guard let (buffer, length) = getDataPointer() else {
            return nil
        }
        return Data(bytes: buffer, count: length)
    }

    func getDataPointer() -> (UnsafeMutablePointer<Int8>, Int)? {
        var length = 0
        var buffer: UnsafeMutablePointer<Int8>?
        guard CMBlockBufferGetDataPointer(
            self,
            atOffset: 0,
            lengthAtOffsetOut: nil,
            totalLengthOut: &length,
            dataPointerOut: &buffer
        ) == noErr else {
            return nil
        }
        guard let buffer else {
            return nil
        }
        return (buffer, length)
    }

    func copyDataBytes(fromOffset: Int, length: Int, to: UnsafeMutableRawPointer) {
        CMBlockBufferCopyDataBytes(
            self,
            atOffset: fromOffset,
            dataLength: length,
            destination: to
        )
    }
}
