import Foundation

enum CUtil {
    static func getString(
        _ lambda: (UnsafeMutablePointer<CChar>?, Int32) -> Int32
    ) throws -> String {
        let size = try RTCError.check(lambda(nil, 0))
        var buffer = [CChar](repeating: 0, count: Int(size))
        _ = lambda(&buffer, Int32(size))
        return String(cString: &buffer)
    }

    static func getUInt32(
        _ lambda: (UnsafeMutablePointer<UInt32>?, Int32) -> Int32
    ) throws -> UInt32 {
        let size = try RTCError.check(lambda(nil, 0))
        var buffer: UInt32 = 0
        _ = lambda(&buffer, Int32(size))
        return buffer
    }
}
