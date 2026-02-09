import libdatachannel

public enum RTCTransportPolicy: Sendable, Encodable {
    case all
    case relay
}

extension RTCTransportPolicy {
    var cValue: rtcTransportPolicy {
        switch self {
        case .all:
            return RTC_TRANSPORT_POLICY_ALL
        case .relay:
            return RTC_TRANSPORT_POLICY_RELAY
        }
    }
}
