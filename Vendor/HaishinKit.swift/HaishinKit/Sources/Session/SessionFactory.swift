import Foundation

/// A type that represents a streaming session factory.
public protocol SessionFactory {
    /// The supported protocols.
    var supportedProtocols: Set<String> { get }

    /// Makes a new session by uri.
    func make(_ uri: URL, mode: SessionMode, configuration: (any SessionConfiguration)?) -> any Session
}
