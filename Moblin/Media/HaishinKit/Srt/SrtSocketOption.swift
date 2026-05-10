import Foundation
import libsrt

private let enummapTranstype: [String: Any] = [
    "live": SRTT_LIVE,
    "file": SRTT_FILE,
]

enum SrtSocketOption: String {
    static func from(uri: URL?) -> [SrtSocketOption: String] {
        guard let uri else {
            return [:]
        }
        let queryItems = getQueryItems(uri: uri)
        var options: [SrtSocketOption: String] = [:]
        for item in queryItems {
            guard let option = SrtSocketOption(rawValue: item.key) else {
                logger.info("Unknown option: \(item.key)")
                continue
            }
            options[option] = item.value
        }
        return options
    }

    enum `Type`: Int {
        case string
        case int
        case int64
        case bool
        case enumeration
    }

    enum Binding: Int {
        case pre
        case post
    }

    case mss
    case sndsyn
    case rcvsyn
    case isn
    case fc
    case sndbuf
    case rcvbuf
    case linger
    case udpsndbuf
    case udprcvbuf
    case rendezvous
    case sndtimeo
    case rcvtimeo
    case reuseaddr
    case maxbw
    case state
    case event
    case snddata
    case rcvdata
    case sender
    case tsbdmode
    case latency
    case inputbw
    case oheadbw
    case passphrase
    case pbkeylen
    case kmstate
    case ipttl
    case iptos
    case tlpktdrop
    case snddropdelay
    case nakreport
    case conntimeo
    case sndkmstate
    case lossmaxttl
    case rcvlatency
    case peerlatency
    case minversion
    case streamid
    case messageapi
    case payloadsize
    case transtype
    case kmrefreshrate
    case kmpreannounce
    case maxrexmitbw
    case srtlaPatches

    private var symbol: SRT_SOCKOPT {
        switch self {
        case .rcvsyn:
            SRTO_RCVSYN
        case .maxbw:
            SRTO_MAXBW
        case .pbkeylen:
            SRTO_PBKEYLEN
        case .passphrase:
            SRTO_PASSPHRASE
        case .mss:
            SRTO_MSS
        case .fc:
            SRTO_FC
        case .sndbuf:
            SRTO_SNDBUF
        case .rcvbuf:
            SRTO_RCVBUF
        case .ipttl:
            SRTO_IPTTL
        case .iptos:
            SRTO_IPTOS
        case .inputbw:
            SRTO_INPUTBW
        case .oheadbw:
            SRTO_OHEADBW
        case .latency:
            SRTO_LATENCY
        case .tsbdmode:
            SRTO_TSBPDMODE
        case .tlpktdrop:
            SRTO_TLPKTDROP
        case .nakreport:
            SRTO_NAKREPORT
        case .conntimeo:
            SRTO_CONNTIMEO
        case .lossmaxttl:
            SRTO_LOSSMAXTTL
        case .rcvlatency:
            SRTO_RCVLATENCY
        case .peerlatency:
            SRTO_PEERLATENCY
        case .minversion:
            SRTO_MINVERSION
        case .streamid:
            SRTO_STREAMID
        case .messageapi:
            SRTO_MESSAGEAPI
        case .payloadsize:
            SRTO_PAYLOADSIZE
        case .transtype:
            SRTO_TRANSTYPE
        case .kmrefreshrate:
            SRTO_KMREFRESHRATE
        case .kmpreannounce:
            SRTO_KMPREANNOUNCE
        case .maxrexmitbw:
            SRTO_MAXREXMITBW
        case .sndsyn:
            SRTO_SNDSYN
        case .isn:
            SRTO_ISN
        case .linger:
            SRTO_LINGER
        case .udpsndbuf:
            SRTO_UDP_SNDBUF
        case .udprcvbuf:
            SRTO_UDP_RCVBUF
        case .rendezvous:
            SRTO_RENDEZVOUS
        case .sndtimeo:
            SRTO_SNDTIMEO
        case .rcvtimeo:
            SRTO_RCVTIMEO
        case .reuseaddr:
            SRTO_REUSEADDR
        case .state:
            SRTO_STATE
        case .event:
            SRTO_EVENT
        case .snddata:
            SRTO_SNDDATA
        case .rcvdata:
            SRTO_RCVDATA
        case .sender:
            SRTO_SENDER
        case .kmstate:
            SRTO_KMSTATE
        case .snddropdelay:
            SRT_SOCKOPT(rawValue: 32)
        case .sndkmstate:
            SRTO_SNDKMSTATE
        case .srtlaPatches:
            SRTO_SRTLAPATCHES
        }
    }

    var binding: Binding {
        switch self {
        case .rcvsyn:
            .pre
        case .maxbw:
            .post
        case .pbkeylen:
            .pre
        case .passphrase:
            .pre
        case .mss:
            .pre
        case .fc:
            .pre
        case .sndbuf:
            .pre
        case .rcvbuf:
            .pre
        case .ipttl:
            .pre
        case .iptos:
            .pre
        case .inputbw:
            .post
        case .oheadbw:
            .post
        case .tsbdmode:
            .pre
        case .latency:
            .pre
        case .tlpktdrop:
            .pre
        case .nakreport:
            .pre
        case .conntimeo:
            .pre
        case .lossmaxttl:
            .pre
        case .rcvlatency:
            .pre
        case .peerlatency:
            .pre
        case .minversion:
            .pre
        case .streamid:
            .pre
        case .messageapi:
            .pre
        case .payloadsize:
            .pre
        case .transtype:
            .pre
        case .kmrefreshrate:
            .pre
        case .kmpreannounce:
            .pre
        case .maxrexmitbw:
            .post
        case .sndsyn:
            .post
        case .isn:
            .post
        case .linger:
            .post
        case .udpsndbuf:
            .pre
        case .udprcvbuf:
            .pre
        case .rendezvous:
            .pre
        case .sndtimeo:
            .post
        case .rcvtimeo:
            .post
        case .reuseaddr:
            .post
        case .state:
            .post
        case .event:
            .post
        case .snddata:
            .post
        case .rcvdata:
            .post
        case .sender:
            .post
        case .kmstate:
            .post
        case .snddropdelay:
            .post
        case .sndkmstate:
            .post
        case .srtlaPatches:
            .pre
        }
    }

    var type: Type {
        switch self {
        case .tsbdmode:
            .bool
        case .rcvsyn:
            .bool
        case .maxbw:
            .int64
        case .pbkeylen:
            .int
        case .passphrase:
            .string
        case .mss:
            .int
        case .fc:
            .int
        case .sndbuf:
            .int
        case .rcvbuf:
            .int
        case .ipttl:
            .int
        case .iptos:
            .int
        case .inputbw:
            .int64
        case .oheadbw:
            .int
        case .latency:
            .int
        case .tlpktdrop:
            .bool
        case .nakreport:
            .bool
        case .conntimeo:
            .int
        case .lossmaxttl:
            .int
        case .rcvlatency:
            .int
        case .peerlatency:
            .int
        case .minversion:
            .int
        case .streamid:
            .string
        case .messageapi:
            .bool
        case .payloadsize:
            .int
        case .transtype:
            .enumeration
        case .kmrefreshrate:
            .int
        case .kmpreannounce:
            .int
        case .maxrexmitbw:
            .int64
        case .sndsyn:
            .bool
        case .isn:
            .int
        case .linger:
            .int
        case .udpsndbuf:
            .int
        case .udprcvbuf:
            .int
        case .rendezvous:
            .bool
        case .sndtimeo:
            .int
        case .rcvtimeo:
            .int
        case .reuseaddr:
            .bool
        case .state:
            .int
        case .event:
            .int
        case .snddata:
            .int
        case .rcvdata:
            .int
        case .sender:
            .int
        case .kmstate:
            .int
        case .snddropdelay:
            .int
        case .sndkmstate:
            .int
        case .srtlaPatches:
            .bool
        }
    }

    var valmap: [String: Any]? {
        switch self {
        case .transtype:
            enummapTranstype
        default:
            nil
        }
    }

    func setOption(_ socket: SRTSOCKET, value: String) -> Bool {
        guard let data = data(value) else {
            return false
        }
        let result: Int32 = data.withUnsafeBytes { pointer in
            guard let buffer = pointer.baseAddress else {
                return -1
            }
            return srt_setsockopt(socket, 0, symbol, buffer, Int32(data.count))
        }
        return result != -1
    }

    func data(_ value: String) -> Data? {
        switch type {
        case .string:
            return String(describing: value).data(using: .utf8)
        case .int:
            guard var value = Int32(value) else {
                return nil
            }
            return .init(Data(bytes: &value, count: MemoryLayout.size(ofValue: value)))
        case .int64:
            guard var value = Int64(value) else {
                return nil
            }
            return .init(Data(bytes: &value, count: MemoryLayout.size(ofValue: value)))
        case .bool:
            guard var value = Int32(value) else {
                return nil
            }
            value = (value != 0 ? 1 : 0)
            return .init(Data(bytes: &value, count: MemoryLayout.size(ofValue: value)))
        case .enumeration:
            switch self {
            case .transtype:
                let key = value
                guard var v = valmap?[key] as? SRT_TRANSTYPE else {
                    return nil
                }
                return .init(Data(bytes: &v, count: MemoryLayout.size(ofValue: value)))
            default:
                return nil
            }
        }
    }

    static func configure(_ socket: SRTSOCKET,
                          binding: Binding,
                          options: [SrtSocketOption: String]) -> [String]
    {
        var failures: [String] = []
        for (key, value) in options where key.binding == binding {
            if !key.setOption(socket, value: value) { failures.append(key.rawValue) }
        }
        return failures
    }

    static func getQueryItems(uri: URL) -> [String: String] {
        guard let urlComponent = URLComponents(string: uri.absoluteString) else {
            return [:]
        }
        guard let queryItems = urlComponent.queryItems else {
            return [:]
        }
        var params: [String: String] = [:]
        for item in queryItems {
            params[item.name] = item.value?.removingPercentEncoding ?? ""
        }
        return params
    }
}
