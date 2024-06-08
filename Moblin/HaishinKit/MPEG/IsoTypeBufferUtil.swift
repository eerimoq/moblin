import Foundation

struct IsoTypeBufferUtil {
    static func toNALFileFormat(_ data: inout Data) {
        var lastIndexOf = data.count - 1
        for i in (2 ..< data.count).reversed() {
            guard data[i] == 1, data[i - 1] == 0, data[i - 2] == 0 else {
                continue
            }
            let startCodeLength = i - 3 >= 0 && data[i - 3] == 0 ? 4 : 3
            let start = 4 - startCodeLength
            let length = lastIndexOf - i
            if length > 0 {
                data.replaceSubrange(
                    i - startCodeLength + 1 ... i,
                    with: Int32(length).bigEndian.data[start...]
                )
                lastIndexOf = i - startCodeLength
            }
        }
    }
}
