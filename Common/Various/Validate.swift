import Foundation

func isValidPort(value: String) -> String? {
    guard let port = UInt(value) else {
        return String(localized: "Not a number")
    }
    guard port > 0 else {
        return String(localized: "Too small")
    }
    guard port <= UInt16.max else {
        return String(localized: "Too big")
    }
    return nil
}

func isValidAudioBitrate(bitrate: Int) -> Bool {
    guard bitrate >= 32000, bitrate <= 320_000 else {
        return false
    }
    guard bitrate % 32000 == 0 else {
        return false
    }
    return true
}

func isValidRtmpUrl(url: String, rtmpStreamKeyRequired: Bool) -> String? {
    if !rtmpStreamKeyRequired {
        return nil
    }
    if makeRtmpUri(url: url) == "" {
        return String(localized: "Malformed RTMP URL")
    }
    if makeRtmpStreamKey(url: url) == "" {
        return String(localized: "RTMP stream key missing")
    }
    return nil
}

func isValidSrtUrl(url: String) -> String? {
    guard let url = URL(string: url) else {
        return String(localized: "Malformed SRT(LA) URL")
    }
    if url.port == nil {
        return String(localized: "SRT(LA) port number missing")
    }
    return nil
}

func isValidRistUrl(url: String) -> String? {
    guard let url = URL(string: url) else {
        return String(localized: "Malformed RIST URL")
    }
    if url.port == nil {
        return String(localized: "RIST port number missing")
    }
    return nil
}

private func isValidIrlUrl(url: String) -> String? {
    guard URL(string: url) != nil else {
        return String(localized: "Malformed IRL URL")
    }
    return nil
}

func isValidUrl(url value: String,
                allowedSchemes: [String]? = nil,
                rtmpStreamKeyRequired: Bool = true) -> String?
{
    guard let url = URL(string: value) else {
        return String(localized: "Malformed URL")
    }
    if url.host() == nil {
        return String(localized: "Host missing")
    }
    if let port = url.port {
        guard port > 0, port <= UInt16.max else {
            return String(localized: "Bad port")
        }
    }
    guard URLComponents(url: url, resolvingAgainstBaseURL: false) != nil else {
        return String(localized: "Malformed URL")
    }
    if let allowedSchemes, let scheme = url.scheme {
        if !allowedSchemes.contains(scheme) {
            return "Only \(allowedSchemes.joined(separator: " and ")) allowed, not \(scheme)"
        }
    }
    switch url.scheme {
    case "rtmp":
        if let message = isValidRtmpUrl(url: value, rtmpStreamKeyRequired: rtmpStreamKeyRequired) {
            return message
        }
    case "rtmps":
        if let message = isValidRtmpUrl(url: value, rtmpStreamKeyRequired: rtmpStreamKeyRequired) {
            return message
        }
    case "srt":
        if let message = isValidSrtUrl(url: value) {
            return message
        }
    case "srtla":
        if let message = isValidSrtUrl(url: value) {
            return message
        }
    case "rist":
        if let message = isValidRistUrl(url: value) {
            return message
        }
    case "whip":
        break
    case "irl":
        if let message = isValidIrlUrl(url: value) {
            return message
        }
    case nil:
        return String(localized: "Scheme missing")
    default:
        return String(localized: "Unsupported scheme \(url.scheme!)")
    }
    return nil
}

func isValidWebSocketUrl(url value: String) -> String? {
    if value.isEmpty {
        return nil
    }
    guard let url = URL(string: value) else {
        return String(localized: "Malformed URL")
    }
    if url.host() == nil {
        return String(localized: "Host missing")
    }
    guard URLComponents(url: url, resolvingAgainstBaseURL: false) != nil else {
        return String(localized: "Malformed URL")
    }
    switch url.scheme {
    case "ws":
        break
    case "wss":
        break
    case nil:
        return String(localized: "Scheme missing")
    default:
        return String(localized: "Unsupported scheme \(url.scheme!)")
    }
    return nil
}

func isValidHttpUrl(url value: String) -> String? {
    if value.isEmpty {
        return nil
    }
    guard let url = URL(string: value) else {
        return String(localized: "Malformed URL")
    }
    if url.host() == nil {
        return String(localized: "Host missing")
    }
    guard URLComponents(url: url, resolvingAgainstBaseURL: false) != nil else {
        return String(localized: "Malformed URL")
    }
    switch url.scheme {
    case "http":
        break
    case "https":
        break
    case nil:
        return String(localized: "Scheme missing")
    default:
        return String(localized: "Unsupported scheme \(url.scheme!)")
    }
    return nil
}
