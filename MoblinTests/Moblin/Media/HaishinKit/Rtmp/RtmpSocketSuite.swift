import Foundation
@testable import Moblin
import Testing

private final class SocketDelegateMock: RtmpSocketDelegate {
    var numberOfCloses = 0
    var disconnectCodes: [RtmpStatusCode] = []

    func socketHandshakeDone(_: RtmpSocket) {}

    func socketClosed(_: RtmpSocket) {
        numberOfCloses += 1
    }

    func socketDisconnected(_: RtmpSocket, code: RtmpStatusCode) {
        disconnectCodes.append(code)
    }

    func socketDataReceived(_: RtmpSocket, data: Data) -> Data {
        data
    }

    func socketUpdateStats(_: RtmpSocket, totalBytesSent _: Int64) {}
}

struct RtmpSocketSuite {
    @Test
    func closeReportsDisconnectBeforeHandshake() {
        let delegate = SocketDelegateMock()
        let socket = RtmpSocket(name: "test", queue: DispatchQueue(label: "test"))
        socket.delegate = delegate
        socket.close(isDisconnected: true)
        #expect(socket.readyState == .closed)
        #expect(delegate.numberOfCloses == 1)
        #expect(delegate.disconnectCodes == [.connectFailed])
    }

    @Test
    func closeWithoutDisconnectDoesNotReportDisconnect() {
        let delegate = SocketDelegateMock()
        let socket = RtmpSocket(name: "test", queue: DispatchQueue(label: "test"))
        socket.delegate = delegate
        socket.close(isDisconnected: false)
        #expect(delegate.numberOfCloses == 1)
        #expect(delegate.disconnectCodes.isEmpty)
    }

    @Test
    func secondCloseDoesNothing() {
        let delegate = SocketDelegateMock()
        let socket = RtmpSocket(name: "test", queue: DispatchQueue(label: "test"))
        socket.delegate = delegate
        socket.close(isDisconnected: false)
        socket.close(isDisconnected: true)
        #expect(delegate.numberOfCloses == 1)
        #expect(delegate.disconnectCodes.isEmpty)
    }
}
