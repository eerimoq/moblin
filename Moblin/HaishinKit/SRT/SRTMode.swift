import Foundation
import libsrt

enum SRTMode {
    case caller
    case listener

    func host(_ host: String) -> String {
        switch self {
        case .caller:
            return host
        case .listener:
            return "0.0.0.0"
        }
    }

    func open(_ u: SRTSOCKET, _ sockaddr: UnsafePointer<sockaddr>, _ namelen: Int32) -> Int32 {
        switch self {
        case .caller:
            return srt_connect(u, sockaddr, namelen)
        case .listener:
            return srt_bind(u, sockaddr, namelen)
        }
    }
}
