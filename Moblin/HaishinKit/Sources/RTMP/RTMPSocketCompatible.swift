import Foundation

enum RTMPSocketReadyState: UInt8 {
    case uninitialized = 0
    case versionSent = 1
    case ackSent = 2
    case handshakeDone = 3
    case closing = 4
    case closed = 5
}

protocol RTMPSocketCompatible: AnyObject {
    var timeout: Int { get set }
    var delegate: (any RTMPSocketDelegate)? { get set }
    var connected: Bool { get }
    var timestamp: TimeInterval { get }
    var readyState: RTMPSocketReadyState { get set }
    var chunkSizeC: Int { get set }
    var chunkSizeS: Int { get set }
    var inputBuffer: Data { get set }
    var totalBytesIn: Atomic<Int64> { get }
    var totalBytesOut: Atomic<Int64> { get }
    var securityLevel: StreamSocketSecurityLevel { get set }
    var qualityOfService: DispatchQoS { get set }

    @discardableResult
    func doOutput(chunk: RTMPChunk) -> Int
    func close(isDisconnected: Bool)
    func connect(withName: String, port: Int)
    func setProperty(_ value: Any?, forKey: String)
    func didTimeout()
}

extension RTMPSocketCompatible {
    func setProperty(_: Any?, forKey _: String) {}

    func didTimeout() {
        close(isDisconnected: false)
        delegate?.dispatch(.ioError, bubbles: false, data: nil)
        logger.info("connection timedout")
    }
}

// swiftlint:disable:next class_delegate_protocol
protocol RTMPSocketDelegate: EventDispatcherConvertible {
    func socket(_ socket: any RTMPSocketCompatible, data: Data)
    func socket(_ socket: any RTMPSocketCompatible, readyState: RTMPSocketReadyState)
    func socket(_ socket: any RTMPSocketCompatible, totalBytesIn: Int64)
    func socket(_ socket: any RTMPSocketCompatible, totalBytesOut: Int64)
}
