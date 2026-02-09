import Foundation

enum SdpMediaType: String {
    case audio
    case video
}

struct SdpMediaDescription {
    var type: SdpMediaType
    var port: Int
    var proto: String
    var formats: [String]
    var attributes: [String: [String]]
    var mid: String?
    var iceUfrag: String?
    var icePwd: String?
    var iceOptions: String?
    var fingerprint: String?
    var setup: String?
    var candidates: [SdpCandidate]
    var ssrc: UInt32?
    var payloadType: Int?
    var rtpmap: String?
    var fmtp: String?

    init(type: SdpMediaType) {
        self.type = type
        port = 9
        proto = "UDP/TLS/RTP/SAVPF"
        formats = []
        attributes = [:]
        candidates = []
    }
}

struct SdpCandidate {
    var foundation: String
    var component: Int
    var transport: String
    var priority: UInt32
    var address: String
    var port: Int
    var type: String

    func toSdpLine() -> String {
        return "a=candidate:\(foundation) \(component) \(transport) \(priority) " +
            "\(address) \(port) typ \(type)"
    }
}

struct SdpMessage {
    var version: Int = 0
    var origin: String = "- 0 0 IN IP4 0.0.0.0"
    var sessionName: String = "-"
    var timing: String = "0 0"
    var bundleGroup: String?
    var media: [SdpMediaDescription] = []
    var iceUfrag: String?
    var icePwd: String?
    var iceOptions: String?
    var fingerprint: String?
    var setup: String?

    func encode() -> String {
        var lines: [String] = []
        lines.append("v=\(version)")
        lines.append("o=\(origin)")
        lines.append("s=\(sessionName)")
        lines.append("t=\(timing)")
        if let bundleGroup {
            lines.append("a=group:BUNDLE \(bundleGroup)")
        }
        if let iceUfrag {
            lines.append("a=ice-ufrag:\(iceUfrag)")
        }
        if let icePwd {
            lines.append("a=ice-pwd:\(icePwd)")
        }
        if let iceOptions {
            lines.append("a=ice-options:\(iceOptions)")
        }
        if let fingerprint {
            lines.append("a=fingerprint:\(fingerprint)")
        }
        if let setup {
            lines.append("a=setup:\(setup)")
        }
        for mediaDesc in media {
            let formatList = mediaDesc.formats.joined(separator: " ")
            lines.append("m=\(mediaDesc.type.rawValue) \(mediaDesc.port) \(mediaDesc.proto) \(formatList)")
            lines.append("c=IN IP4 0.0.0.0")
            if let mid = mediaDesc.mid {
                lines.append("a=mid:\(mid)")
            }
            if let iceUfrag = mediaDesc.iceUfrag {
                lines.append("a=ice-ufrag:\(iceUfrag)")
            }
            if let icePwd = mediaDesc.icePwd {
                lines.append("a=ice-pwd:\(icePwd)")
            }
            if let fingerprint = mediaDesc.fingerprint {
                lines.append("a=fingerprint:\(fingerprint)")
            }
            if let setup = mediaDesc.setup {
                lines.append("a=setup:\(setup)")
            }
            if let rtpmap = mediaDesc.rtpmap {
                let pt = mediaDesc.formats.first ?? "0"
                lines.append("a=rtpmap:\(pt) \(rtpmap)")
            }
            if let fmtp = mediaDesc.fmtp {
                let pt = mediaDesc.formats.first ?? "0"
                lines.append("a=fmtp:\(pt) \(fmtp)")
            }
            lines.append("a=sendonly")
            lines.append("a=rtcp-mux")
            if let ssrc = mediaDesc.ssrc {
                lines.append("a=ssrc:\(ssrc) cname:moblin")
            }
            for candidate in mediaDesc.candidates {
                lines.append(candidate.toSdpLine())
            }
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    static func decode(from sdpString: String) -> SdpMessage {
        var message = SdpMessage()
        var currentMedia: SdpMediaDescription?
        let lines = sdpString.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 2, trimmed[trimmed.index(trimmed.startIndex, offsetBy: 1)] == "=" else {
                continue
            }
            let type = trimmed[trimmed.startIndex]
            let value = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 2)...])
            switch type {
            case "v":
                message.version = Int(value) ?? 0
            case "o":
                message.origin = value
            case "s":
                message.sessionName = value
            case "t":
                message.timing = value
            case "m":
                if let media = currentMedia {
                    message.media.append(media)
                }
                currentMedia = parseMediaLine(value)
            case "a":
                if var media = currentMedia {
                    parseAttribute(value, media: &media)
                    currentMedia = media
                } else {
                    parseSessionAttribute(value, message: &message)
                }
            default:
                break
            }
        }
        if let media = currentMedia {
            message.media.append(media)
        }
        return message
    }

    private static func parseMediaLine(_ value: String) -> SdpMediaDescription? {
        let parts = value.split(separator: " ", maxSplits: 3)
        guard parts.count >= 4 else {
            return nil
        }
        guard let mediaType = SdpMediaType(rawValue: String(parts[0])) else {
            return nil
        }
        var media = SdpMediaDescription(type: mediaType)
        media.port = Int(parts[1]) ?? 9
        media.proto = String(parts[2])
        media.formats = parts[3].split(separator: " ").map { String($0) }
        return media
    }

    private static func parseAttribute(_ value: String, media: inout SdpMediaDescription) {
        let parts = value.split(separator: ":", maxSplits: 1)
        let key = String(parts[0])
        let attrValue = parts.count > 1 ? String(parts[1]) : ""
        switch key {
        case "mid":
            media.mid = attrValue
        case "ice-ufrag":
            media.iceUfrag = attrValue
        case "ice-pwd":
            media.icePwd = attrValue
        case "fingerprint":
            media.fingerprint = attrValue
        case "setup":
            media.setup = attrValue
        case "candidate":
            if let candidate = parseCandidateLine(attrValue) {
                media.candidates.append(candidate)
            }
        case "ssrc":
            let ssrcParts = attrValue.split(separator: " ", maxSplits: 1)
            if let ssrcValue = UInt32(ssrcParts[0]) {
                media.ssrc = ssrcValue
            }
        case "rtpmap":
            let rtpmapParts = attrValue.split(separator: " ", maxSplits: 1)
            if rtpmapParts.count == 2 {
                if media.payloadType == nil {
                    media.payloadType = Int(rtpmapParts[0])
                }
                media.rtpmap = String(rtpmapParts[1])
            }
        case "fmtp":
            let fmtpParts = attrValue.split(separator: " ", maxSplits: 1)
            if fmtpParts.count == 2 {
                media.fmtp = String(fmtpParts[1])
            }
        default:
            break
        }
    }

    private static func parseSessionAttribute(_ value: String, message: inout SdpMessage) {
        let parts = value.split(separator: ":", maxSplits: 1)
        let key = String(parts[0])
        let attrValue = parts.count > 1 ? String(parts[1]) : ""
        switch key {
        case "group":
            if attrValue.hasPrefix("BUNDLE ") {
                message.bundleGroup = String(attrValue.dropFirst(7))
            }
        case "ice-ufrag":
            message.iceUfrag = attrValue
        case "ice-pwd":
            message.icePwd = attrValue
        case "ice-options":
            message.iceOptions = attrValue
        case "fingerprint":
            message.fingerprint = attrValue
        case "setup":
            message.setup = attrValue
        default:
            break
        }
    }

    private static func parseCandidateLine(_ value: String) -> SdpCandidate? {
        let parts = value.split(separator: " ")
        guard parts.count >= 7 else {
            return nil
        }
        guard let component = Int(parts[1]),
              let priority = UInt32(parts[3]),
              let port = Int(parts[5])
        else {
            return nil
        }
        var candidateType = "host"
        for i in 6 ..< parts.count - 1 where parts[i] == "typ" {
            candidateType = String(parts[i + 1])
        }
        return SdpCandidate(
            foundation: String(parts[0]),
            component: component,
            transport: String(parts[2]),
            priority: priority,
            address: String(parts[4]),
            port: port,
            type: candidateType
        )
    }
}

func sdpCreateOffer(
    videoSsrc: UInt32,
    audioSsrc: UInt32,
    videoPayloadType: UInt8,
    audioPayloadType: UInt8,
    iceUfrag: String,
    icePwd: String,
    fingerprint: String
) -> SdpMessage {
    var sdp = SdpMessage()
    sdp.iceUfrag = iceUfrag
    sdp.icePwd = icePwd
    sdp.fingerprint = fingerprint
    sdp.setup = "actpass"
    sdp.bundleGroup = "0 1"
    var audio = SdpMediaDescription(type: .audio)
    audio.formats = [String(audioPayloadType)]
    audio.mid = "0"
    audio.rtpmap = "opus/48000/2"
    audio.ssrc = audioSsrc
    sdp.media.append(audio)
    var video = SdpMediaDescription(type: .video)
    video.formats = [String(videoPayloadType)]
    video.mid = "1"
    video.rtpmap = "H264/90000"
    video.fmtp = "level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42e01f"
    video.ssrc = videoSsrc
    sdp.media.append(video)
    return sdp
}
