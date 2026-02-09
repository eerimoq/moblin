import libdatachannel

public enum SDPSessionDescriptionType: String, Sendable {
    case answer
    case offer
    case pranswer
    case rollback
}
