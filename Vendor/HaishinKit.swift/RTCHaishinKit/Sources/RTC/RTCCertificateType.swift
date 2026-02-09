import libdatachannel

public enum RTCCertificateType: Sendable, Encodable {
    case `default`
    case ECDSA
    case RSA
}

extension RTCCertificateType {
    var cValue: rtcCertificateType {
        switch self {
        case .default:
            return RTC_CERTIFICATE_DEFAULT
        case .ECDSA:
            return RTC_CERTIFICATE_ECDSA
        case .RSA:
            return RTC_CERTIFICATE_RSA
        }
    }
}
