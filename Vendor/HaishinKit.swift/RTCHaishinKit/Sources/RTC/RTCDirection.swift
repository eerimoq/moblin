import libdatachannel

public enum RTCDirection: Sendable {
    case unknown
    case sendrecv
    case sendonly
    case recvonly
    case inactive

    var cValue: rtcDirection {
        switch self {
        case .unknown:
            return RTC_DIRECTION_UNKNOWN
        case .sendrecv:
            return RTC_DIRECTION_SENDRECV
        case .sendonly:
            return RTC_DIRECTION_SENDONLY
        case .recvonly:
            return RTC_DIRECTION_RECVONLY
        case .inactive:
            return RTC_DIRECTION_INACTIVE
        }
    }
}
