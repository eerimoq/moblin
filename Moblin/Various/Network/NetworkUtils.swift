import Foundation
import Network
import WebKit

extension NWPath {
    // The list contains duplicates since iOS 26. Apple bug?
    func uniqueAvailableInterfaces() -> [NWInterface] {
        var interfaces: [NWInterface] = []
        for interface in availableInterfaces where !interfaces.contains(interface) {
            interfaces.append(interface)
        }
        return interfaces
    }
}

extension NWEndpoint.Port {
    init(integer: Int) {
        self.init(integerLiteral: UInt16(clamping: integer))
    }
}

extension NWConnection.ContentContext {
    func webSocketOperation() -> NWProtocolWebSocket.Opcode? {
        let definitions = protocolMetadata(definition: NWProtocolWebSocket.definition) as? Network
            .NWProtocolWebSocket
            .Metadata
        return definitions?.opcode
    }
}

extension NWConnection {
    func sendWebSocket(data: Data?,
                       opcode: NWProtocolWebSocket.Opcode,
                       completion: NWConnection.SendCompletion = .idempotent)
    {
        let metadata = NWProtocolWebSocket.Metadata(opcode: opcode)
        let context = NWConnection.ContentContext(identifier: "context", metadata: [metadata])
        send(content: data, contentContext: context, isComplete: true, completion: completion)
    }
}

enum NetworkResponse<T> {
    case success(T)
    case authError
    case error

    func isSuccessful() -> Bool {
        switch self {
        case .success:
            true
        default:
            false
        }
    }
}

typealias OperationResult = NetworkResponse<Data>

func makeUrl(_ path: String, _ parameters: [(String, String)]) -> String {
    var components = URLComponents()
    components.path = path
    components.queryItems = parameters.map { URLQueryItem(name: $0, value: $1) }
    return components.string ?? ""
}

func makeMdnsHostname(deviceName: String) -> String {
    let name = deviceName
        .lowercased()
        .replace(" ", "-")
        .replacing(/-+/, with: "-")
        .trimmingCharacters(in: ["-"])
        .replacing(/[^\w\d-]/, with: "")
    return "\(name).local"
}

func httpRequest(request: URLRequest,
                 queue: DispatchQueue = .main,
                 completion: ((Data?, URLResponse?, (any Error)?) -> Void)? = nil)
{
    nonisolated(unsafe) let completion = completion
    httpUrlSession().dataTask(with: request) { data, response, error in
        queue.async {
            completion?(data, response, error)
        }
    }.resume()
}

func httpGet(from: URL) async throws -> (Data, HTTPURLResponse) {
    let (data, response) = try await httpUrlSession().data(from: from)
    if let response = response.http {
        return (data, response)
    } else {
        throw "Not an HTTP response"
    }
}

func httpGet(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let (data, response) = try await httpUrlSession().data(for: request)
    if let response = response.http {
        return (data, response)
    } else {
        throw "Not an HTTP response"
    }
}

func getHttpsUrl(text: String) -> URL? {
    if text.starts(with: "https://"), let url = URL(string: text.trim()) {
        return url
    }
    return nil
}

extension WKWebViewConfiguration {
    func setHttpProxy(endpoint: NWEndpoint?) {
        guard #available(iOS 17, *) else {
            return
        }
        if let endpoint {
            websiteDataStore.proxyConfigurations = [
                .init(httpCONNECTProxy: endpoint),
            ]
        } else {
            websiteDataStore.proxyConfigurations = []
        }
    }
}

extension URL {
    func isLoopback() -> Bool {
        guard let host = host()?.trimmingCharacters(in: ["[", "]"]) else {
            return false
        }
        if host == "localhost" {
            return true
        }
        if let address = IPv4Address(host) {
            return address.isLoopback
        }
        if let address = IPv6Address(host) {
            return address.isLoopback
        }
        return false
    }
}

extension NWEndpoint {
    func isLocalNetwork() -> Bool {
        guard case let .hostPort(host, _) = self else {
            return false
        }
        return host.isLocalNetwork()
    }
}

extension NWEndpoint.Host {
    func isLocalNetwork() -> Bool {
        switch self {
        case let .ipv4(address):
            address.isLoopback || address.isLinkLocal || address.isPrivate()
        case let .ipv6(address):
            address.isLoopback || address.isLinkLocal || address.isUniqueLocal
        case let .name(name, _):
            name == "localhost" || name.hasSuffix(".local")
        @unknown default:
            false
        }
    }
}

extension IPv4Address {
    func isPrivate() -> Bool {
        let bytes = [UInt8](rawValue)
        guard bytes.count == 4 else {
            return false
        }
        return bytes[0] == 10
            || (bytes[0] == 172 && (16 ... 31).contains(bytes[1]))
            || (bytes[0] == 192 && bytes[1] == 168)
    }
}
