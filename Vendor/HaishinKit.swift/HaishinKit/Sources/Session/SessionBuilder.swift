import Foundation

/// An actor that provides builder for Session object.
public actor SessionBuilder {
    private let factory: SessionBuilderFactory
    private let uri: URL
    private var mode: SessionMode = .publish
    private var configuration: (any SessionConfiguration)?

    init(factory: SessionBuilderFactory, uri: URL) {
        self.factory = factory
        self.uri = uri
    }

    /// Sets a method.
    public func setMode(_ mode: SessionMode) -> Self {
        self.mode = mode
        return self
    }

    /// Sets a config.
    public func setConfiguration(_ configuration: (any SessionConfiguration)?) -> Self {
        self.configuration = configuration
        return self
    }

    /// Creates a Session instance with the specified fields.
    public func build() async throws -> (any Session)? {
        return try await factory.build(uri, method: mode, configuration: configuration)
    }
}
