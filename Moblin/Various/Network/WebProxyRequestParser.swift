import Foundation

enum WebProxyRequest: Equatable {
    case connect(host: String, port: UInt16, headerLength: Int)
    case http(host: String, port: UInt16, request: Data)
}

private struct WebProxyRequestHeader {
    let name: String
    let lowercasedName: String
    let value: String

    init(name: String, value: String) {
        self.name = name
        lowercasedName = name.lowercased()
        self.value = value
    }
}

private let webProxyRequestHeadersToRemove = ["proxy-connection", "proxy-authorization"]

final class WebProxyRequestParser: HttpParser {
    func parse() -> (Bool, WebProxyRequest?) {
        var offset = 0
        guard let (startLine, nextLineOffset) = getLine(data: data, offset: offset) else {
            return (false, nil)
        }
        offset = nextLineOffset
        let startParts = startLine.split(separator: " ")
        guard startParts.count == 3 else {
            return (true, nil)
        }
        let method = String(startParts[0])
        let target = String(startParts[1])
        let version = String(startParts[2])
        guard version.hasPrefix("HTTP/1.") else {
            return (true, nil)
        }
        var headers: [WebProxyRequestHeader] = []
        while let (line, nextLineOffset) = getLine(data: data, offset: offset) {
            if line.isEmpty {
                let headerLength = nextLineOffset
                if method == "CONNECT" {
                    guard let (host, port) = parseHostPort(target, defaultPort: nil) else {
                        return (true, nil)
                    }
                    return (true, .connect(host: host, port: port, headerLength: headerLength))
                }
                return parseHttp(method: method,
                                 target: target,
                                 version: version,
                                 headers: headers,
                                 bodyOffset: nextLineOffset)
            }
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                headers.append(.init(name: String(parts[0]), value: String(parts[1]).trim()))
            }
            offset = nextLineOffset
        }
        return (false, nil)
    }

    private func parseHttp(method: String,
                           target: String,
                           version: String,
                           headers: [WebProxyRequestHeader],
                           bodyOffset: Int) -> (Bool, WebProxyRequest?)
    {
        guard let url = URL(string: target),
              let host = url.host,
              let scheme = url.scheme
        else {
            guard !target.contains("://") else {
                return (true, nil)
            }
            guard let hostHeader = headers.first(where: { $0.lowercasedName == "host" })?.value,
                  let (host, port) = parseHostPort(hostHeader, defaultPort: 80)
            else {
                return (true, nil)
            }
            let request = makeRequest(method: method,
                                      target: target,
                                      version: version,
                                      headers: headers,
                                      bodyOffset: bodyOffset)
            return (true, .http(host: host, port: port, request: request))
        }
        guard scheme == "http" else {
            return (true, nil)
        }
        guard let port = UInt16(exactly: url.port ?? 80), port > 0 else {
            return (true, nil)
        }
        var path = url.path
        if path.isEmpty {
            path = "/"
        }
        if let query = url.query {
            path += "?\(query)"
        }
        let request = makeRequest(method: method,
                                  target: path,
                                  version: version,
                                  headers: headers,
                                  bodyOffset: bodyOffset)
        return (true, .http(host: host, port: port, request: request))
    }

    private func makeRequest(method: String,
                             target: String,
                             version: String,
                             headers: [WebProxyRequestHeader],
                             bodyOffset: Int) -> Data
    {
        var lines = ["\(method) \(target) \(version)"]
        for header in headers where !webProxyRequestHeadersToRemove.contains(header.lowercasedName) {
            lines.append("\(header.name): \(header.value)")
        }
        lines.append("")
        lines.append("")
        var request = lines.joined(separator: "\r\n").utf8Data
        request += data.advanced(by: bodyOffset)
        return request
    }

    private func parseHostPort(_ value: String, defaultPort: UInt16?) -> (String, UInt16)? {
        if value.starts(with: "[") {
            guard let endIndex = value.firstIndex(of: "]") else {
                return nil
            }
            let host = String(value[value.index(after: value.startIndex) ..< endIndex])
            let rest = value[value.index(after: endIndex)...]
            if rest.isEmpty, let defaultPort {
                return (host, defaultPort)
            }
            guard rest.starts(with: ":"),
                  let port = UInt16(rest.dropFirst()),
                  port > 0
            else {
                return nil
            }
            return (host, port)
        }
        let parts = value.split(separator: ":", maxSplits: 1)
        if parts.count == 1, let defaultPort {
            return (String(parts[0]), defaultPort)
        }
        guard parts.count == 2,
              let port = UInt16(parts[1]),
              port > 0
        else {
            return nil
        }
        return (String(parts[0]), port)
    }
}
