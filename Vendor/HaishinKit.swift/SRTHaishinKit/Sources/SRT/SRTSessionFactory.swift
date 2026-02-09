import Foundation
import HaishinKit

public struct SRTSessionFactory: SessionFactory {
    public let supportedProtocols: Set<String> = ["srt"]

    public init() {
    }

    public func make(_ uri: URL, mode: SessionMode, configuration: (any SessionConfiguration)?) -> any Session {
        return SRTSession(uri: uri, mode: mode, configuration: configuration)
    }
}
