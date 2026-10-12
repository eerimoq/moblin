import Foundation
@testable import Moblin
import Network
import Testing

private class ConnectionDelegate: SrtlaServerClientConnectionDelegate {
    func handlePacketFromSrtClient(_: SrtlaServerClientConnection, packet _: Data) {}
}

struct SrtlaServerClientConnectionSuite {
    @Test
    func doesNotRetainDelegate() {
        let nwConnection = NWConnection(host: .ipv4(.loopback), port: 1234, using: .udp)
        let connection = SrtlaServerClientConnection(connection: nwConnection)
        defer {
            connection.delegate = nil
            connection.stop()
        }
        var delegate: ConnectionDelegate? = ConnectionDelegate()
        weak var weakDelegate = delegate
        connection.delegate = delegate
        #expect(connection.delegate === delegate)
        delegate = nil
        #expect(weakDelegate == nil)
        #expect(connection.delegate == nil)
    }
}
