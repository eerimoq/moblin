import libsrt

/// An enumeration that describes the srt connection reject reason.
///
/// - note: The meaning of each reason follows the SRT protocol specification.
/// - seealso: https://github.com/Haivision/srt/blob/master/docs/API.md
public enum SRTRejectReason: Int, Sendable {
    case unknown = 0
    case system = 1
    case peer = 2
    case resource = 3
    case rogue = 4
    case backlog = 5
    case ipe = 6
    case close = 7
    case version = 8
    case rdvcookie = 9
    case badsecret = 10
    case unsecure = 11
    case messageapi = 12
    case congestion = 13
    case filter = 14
    case group = 15
    case timeout = 16
    case crypto = 17

    init?(socket: SRTSOCKET) {
        self.init(rawValue: Int(srt_getrejectreason(socket)))
    }
}
