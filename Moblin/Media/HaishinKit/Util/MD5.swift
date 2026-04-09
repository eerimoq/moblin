import CryptoKit
import Foundation

enum MD5 {
    static func base64(_ message: String) -> String {
        calculate(message).base64EncodedString(options: .lineLength64Characters)
    }

    static func calculate(_ message: String) -> Data {
        let writer = ByteWriter()
        writer.writeUTF8Bytes(message)
        return calculate(writer.data)
    }

    static func calculate(_ data: Data) -> Data {
        var md5 = Insecure.MD5()
        md5.update(data: data)
        return Data(md5.finalize())
    }
}
