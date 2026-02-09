import Foundation

struct SDPMediaDescription {
    enum Error: Swift.Error {
        case invalidArguments(_ sdp: String)
    }

    static let m = "m="
    static let mid = "a=mid:"
    static let fmtp = "a=fmtp:"
    static let rtpmap = "a=rtpmap:"
    static let rtcpFb = "a=rtcp-fb:"

    enum Attribute {
        case rtpmap(payload: UInt8, codec: String, clock: Int, channels: Int?)
        case fmtp(payload: UInt8, params: String)
        case rtcpFb(payload: UInt8, type: String)
        case mid(String)
        case direction(String)
        case rtcpMux
        case other(key: String, value: String?)
    }

    let kind: String
    let payload: UInt8
    let attributes: [Attribute]
}

extension SDPMediaDescription {
    init(sdp: String) throws {
        var kind: String?
        var payload: UInt8?
        var attributes: [Attribute] = []
        let lines = sdp.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n")
        for line in lines {
            switch true {
            case line.hasPrefix(Self.m):
                // m=audio 9 UDP/TLS/RTP/SAVPF 111
                let components = line.dropFirst(Self.m.count).split(separator: " ")
                guard 4 <= components.count else {
                    break
                }
                kind = String(components[0])
                if let _payload = UInt8(components[3]) {
                    payload = _payload
                }
            case line.hasPrefix(Self.mid):
                // a=mid:0
                attributes.append(.mid(String(line.dropFirst(Self.mid.count))))
            case line.hasPrefix(Self.rtpmap):
                // a=rtpmap:111 opus/48000/2
                let components = line.dropFirst(Self.rtpmap.count).split(separator: " ")
                guard 2 <= components.count else {
                    break
                }
                let codec = components[1].split(separator: "/")
                guard 2 <= codec.count else {
                    break
                }
                if let payload = UInt8(components[0]), let clock = Int(codec[1]) {
                    attributes.append(.rtpmap(
                        payload: payload,
                        codec: String(codec[0]),
                        clock: clock,
                        channels: 2 < codec.count ? Int(codec[2]) : nil
                    ))
                }
            case line.hasPrefix(Self.rtcpFb):
                // a=rtcp-fb:96 nack
                let components = line.dropFirst(Self.rtcpFb.count).split(separator: " ")
                guard 2 <= components.count else {
                    break
                }
                if let payload = UInt8(components[0]) {
                    attributes.append(.rtcpFb(payload: payload, type: String(components[1])))
                }
            case line.hasPrefix(Self.fmtp):
                // a=fmtp:111 minptime=10;useinbandfec=1
                let components = line.dropFirst(Self.fmtp.count).split(separator: " ")
                guard 2 <= components.count else {
                    break
                }
                if let payload = UInt8(components[0]) {
                    attributes.append(.fmtp(payload: payload, params: String(components[1])))
                }
            default:
                break
            }
        }
        guard let kind, let payload else {
            throw Error.invalidArguments(sdp)
        }
        self.kind = kind
        self.payload = payload
        self.attributes = attributes
    }
}
