import Foundation
import HaishinKit

public struct HTTPSessionFactory: SessionFactory {
    public let supportedProtocols: Set<String> = ["http", "https"]

    public init() {
    }

    public func make(_ uri: URL, mode: SessionMode, configuration: (any SessionConfiguration)?) -> any Session {
        return HTTPSession(uri: uri, mode: mode, configuration: configuration)
    }
}
