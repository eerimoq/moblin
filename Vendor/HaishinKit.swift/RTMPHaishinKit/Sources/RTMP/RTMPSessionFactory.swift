import Foundation
import HaishinKit

public struct RTMPSessionFactory: SessionFactory {
    public let supportedProtocols: Set<String> = ["rtmp", "rtmps"]

    public init() {
    }

    public func make(_ uri: URL, mode: SessionMode, configuration: (any SessionConfiguration)?) -> any Session {
        return RTMPSession(uri: uri, mode: mode, configuration: configuration)
    }
}
