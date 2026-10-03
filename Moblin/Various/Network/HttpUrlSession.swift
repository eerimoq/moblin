import Foundation
import Network

private struct HttpUrlSessionState: Sendable {
    var session: URLSession = .shared
    var endpoint: NWEndpoint?
}

private let state = Atomic(HttpUrlSessionState())

func setHttpUrlSessionProxyServer(endpoint: NWEndpoint?) {
    state.mutate { state in
        guard state.endpoint != endpoint else {
            return
        }
        state.endpoint = endpoint
        if let configuration = URLSessionConfiguration.proxied(endpoint: endpoint) {
            state.session = URLSession(configuration: configuration)
        } else {
            state.session = .shared
        }
    }
}

func httpUrlSession() -> URLSession {
    state.value.session
}

func isHttpUrlSessionProxied() -> Bool {
    state.value.session !== URLSession.shared
}

extension URLSessionConfiguration {
    static func proxied(endpoint: NWEndpoint?) -> URLSessionConfiguration? {
        guard #available(iOS 17, *), let endpoint else {
            return nil
        }
        let configuration = URLSessionConfiguration.default
        configuration.proxyConfigurations = [.init(httpCONNECTProxy: endpoint)]
        return configuration
    }
}
