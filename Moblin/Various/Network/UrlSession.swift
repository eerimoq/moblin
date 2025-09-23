import Foundation

extension URLSession {
    static func create(httpProxy: HttpProxy?) -> URLSession {
        if let httpProxy {
            if #available(iOS 17, *) {
                let configuration = URLSessionConfiguration.default
                configuration.proxyConfigurations = [
                    .init(httpCONNECTProxy: .hostPort(
                        host: .init(httpProxy.host),
                        port: .init(integerLiteral: httpProxy.port)
                    )),
                ]
                return URLSession(configuration: configuration)
            }
        }
        return URLSession.shared
    }
}
