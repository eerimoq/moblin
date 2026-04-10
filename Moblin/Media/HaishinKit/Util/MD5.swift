import CryptoKit
import Foundation

func calculateMd5Base64(_ message: String) -> String {
    calculateMd5(message).base64EncodedString(options: .lineLength64Characters)
}

func calculateMd5(_ message: String) -> Data {
    return calculateMd5(message.utf8Data)
}

func calculateMd5(_ data: Data) -> Data {
    var md5 = Insecure.MD5()
    md5.update(data: data)
    return Data(md5.finalize())
}
