import Foundation
@testable import Moblin
import Network
import Testing

private enum ClientEvent: Equatable, Sendable {
    case connected
    case disconnected
    case message(String)
}

private enum ServerEvent: Equatable, @unchecked Sendable {
    case text(String)
    case close(NWProtocolWebSocket.CloseCode)
    case disconnected
}

@MainActor
private final class Delegate: WebSocketClientDelegate {
    let events = MessageQueue<ClientEvent>()
    private(set) var disconnections = 0
    private(set) var messages: [String] = []

    func webSocketClientConnected(_: WebSocketClient) {
        events.put(.connected)
    }

    func webSocketClientDisconnected(_: WebSocketClient) {
        disconnections += 1
        events.put(.disconnected)
    }

    func webSocketClientReceiveMessage(_: WebSocketClient, string: String) {
        messages.append(string)
        events.put(.message(string))
    }
}

@MainActor
private final class WebSocketServerMock {
    private let listener: NWListener
    private let ready = MessageQueue<UInt16>()
    private let connections = MessageQueue<NWConnection>()
    let events = MessageQueue<ServerEvent>()
    private(set) var connectionCount = 0
    private var port: UInt16?
    private var connection: NWConnection?

    init(port: UInt16? = nil) throws {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        let options = NWProtocolWebSocket.Options()
        options.autoReplyPing = true
        parameters.defaultProtocolStack.applicationProtocols.insert(options, at: 0)
        if let port {
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
        } else {
            listener = try NWListener(using: parameters)
        }
        listener.stateUpdateHandler = { state in
            MainActor.assumeIsolated {
                self.handleListenerState(state)
            }
        }
        listener.newConnectionHandler = { connection in
            MainActor.assumeIsolated {
                self.handleNewConnection(connection)
            }
        }
        listener.start(queue: .main)
    }

    deinit {
        listener.cancel()
    }

    func url() async -> URL {
        if port == nil {
            port = await ready.get()
        }
        return URL(string: "ws://127.0.0.1:\(port!)")!
    }

    func stop() {
        listener.cancel()
    }

    func expectEvent(_ expected: ServerEvent) async {
        let event = await events.get()
        #expect(event == expected)
    }

    func acceptConnection() async {
        connection = await connections.get()
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
    }

    func send(text: String) {
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        send(content: text.utf8Data, metadata: metadata)
    }

    func close(code: NWProtocolWebSocket.CloseCode) {
        let metadata = NWProtocolWebSocket.Metadata(opcode: .close)
        metadata.closeCode = code
        send(content: nil, metadata: metadata)
    }

    private func send(content: Data?, metadata: NWProtocolWebSocket.Metadata) {
        let context = NWConnection.ContentContext(identifier: "message", metadata: [metadata])
        connection?.send(content: content, contentContext: context, isComplete: true, completion: .idempotent)
    }

    private func handleListenerState(_ state: NWListener.State) {
        if state == .ready, let port = listener.port {
            ready.put(port.rawValue)
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { state in
            MainActor.assumeIsolated {
                if state == .ready {
                    self.connectionCount += 1
                    self.connections.put(connection)
                    self.receive(connection)
                }
            }
        }
        connection.start(queue: .main)
    }

    private func receive(_ connection: NWConnection) {
        connection.receiveMessage { content, context, _, error in
            MainActor.assumeIsolated {
                let metadata = context?.protocolMetadata(definition: NWProtocolWebSocket.definition)
                if let metadata = metadata as? NWProtocolWebSocket.Metadata {
                    switch metadata.opcode {
                    case .text:
                        if let content {
                            self.events.put(.text(String.fromUtf8(data: content)))
                        }
                    case .close:
                        self.events.put(.close(metadata.closeCode))
                    default:
                        break
                    }
                }
                guard error == nil, context?.isFinal != true else {
                    self.events.put(.disconnected)
                    return
                }
                self.receive(connection)
            }
        }
    }
}

@MainActor
private struct Connection {
    let server: WebSocketServerMock
    let delegate: Delegate
    let client: WebSocketClient

    static func make() async throws -> Connection {
        let server = try WebSocketServerMock()
        let delegate = Delegate()
        let client = await WebSocketClient(url: server.url(), loopback: true)
        client.delegate = delegate
        client.start()
        return Connection(server: server, delegate: delegate, client: client)
    }

    static func makeConnected() async throws -> Connection {
        let connection = try await make()
        await connection.server.acceptConnection()
        await connection.expectClientEvent(.connected)
        return connection
    }

    func expectClientEvent(_ expected: ClientEvent) async {
        let event = await delegate.events.get()
        #expect(event == expected)
    }

    func expectServerEvent(_ expected: ServerEvent) async {
        await server.expectEvent(expected)
    }
}

@MainActor
struct WebSocketClientSuite {
    @Test
    func connectSendAndReceive() async throws {
        let connection = try await Connection.make()
        #expect(!connection.client.isConnected())
        await connection.server.acceptConnection()
        await connection.expectClientEvent(.connected)
        #expect(connection.client.isConnected())
        connection.client.send(string: "hello")
        await connection.expectServerEvent(.text("hello"))
        connection.server.send(text: "world")
        await connection.expectClientEvent(.message("world"))
        connection.client.stop()
    }

    @Test
    func closeWithHandshake() async throws {
        let connection = try await Connection.makeConnected()
        connection.client.stop(closeCode: .privateCode(4001))
        #expect(!connection.client.isConnected())
        await connection.expectServerEvent(.close(.privateCode(4001)))
        connection.server.close(code: .privateCode(4001))
        await connection.expectServerEvent(.disconnected)
        try await Task.sleep(for: .seconds(1))
        #expect(connection.delegate.disconnections == 0)
        #expect(connection.server.connectionCount == 1)
    }

    @Test
    func closeWithDefaultCloseCode() async throws {
        let connection = try await Connection.makeConnected()
        connection.client.stop()
        await connection.expectServerEvent(.close(.protocolCode(.normalClosure)))
        connection.server.close(code: .protocolCode(.normalClosure))
        await connection.expectServerEvent(.disconnected)
    }

    @Test
    func closeWithoutPeerResponse() async throws {
        let connection = try await Connection.makeConnected()
        connection.client.stop(closeCode: .privateCode(4002))
        await connection.expectServerEvent(.close(.privateCode(4002)))
        await connection.expectServerEvent(.disconnected)
        #expect(connection.delegate.disconnections == 0)
    }

    @Test
    func messagesAreDroppedWhileClosing() async throws {
        let connection = try await Connection.makeConnected()
        connection.client.stop()
        connection.server.send(text: "late")
        await connection.expectServerEvent(.close(.protocolCode(.normalClosure)))
        connection.server.close(code: .protocolCode(.normalClosure))
        await connection.expectServerEvent(.disconnected)
        #expect(connection.delegate.messages.isEmpty)
    }

    @Test
    func closeWhenClientIsDeallocated() async throws {
        let server = try WebSocketServerMock()
        let delegate = Delegate()
        var client: WebSocketClient? = await WebSocketClient(url: server.url(), loopback: true)
        client?.delegate = delegate
        client?.start()
        await server.acceptConnection()
        let event = await delegate.events.get()
        #expect(event == .connected)
        client?.stop(closeCode: .privateCode(4003))
        client = nil
        await server.expectEvent(.close(.privateCode(4003)))
        server.close(code: .privateCode(4003))
        await server.expectEvent(.disconnected)
    }

    @Test
    func closeWithoutPeerResponseWhenClientIsDeallocated() async throws {
        let server = try WebSocketServerMock()
        let delegate = Delegate()
        var client: WebSocketClient? = await WebSocketClient(url: server.url(), loopback: true)
        client?.delegate = delegate
        client?.start()
        await server.acceptConnection()
        let event = await delegate.events.get()
        #expect(event == .connected)
        client?.stop(closeCode: .privateCode(4004))
        client = nil
        await server.expectEvent(.close(.privateCode(4004)))
        await server.expectEvent(.disconnected)
    }

    @Test
    func sendIsIgnoredWhileClosing() async throws {
        let connection = try await Connection.makeConnected()
        connection.client.stop()
        connection.client.send(string: "ignored")
        await connection.expectServerEvent(.close(.protocolCode(.normalClosure)))
        connection.server.close(code: .protocolCode(.normalClosure))
        await connection.expectServerEvent(.disconnected)
    }

    @Test
    func reconnectAfterServerClose() async throws {
        let connection = try await Connection.makeConnected()
        connection.server.close(code: .privateCode(4000))
        await connection.expectClientEvent(.disconnected)
        #expect(!connection.client.isConnected())
        await connection.server.acceptConnection()
        await connection.expectClientEvent(.connected)
        #expect(connection.client.isConnected())
        connection.client.stop()
    }

    @Test
    func reconnectAfterServerDisconnect() async throws {
        let connection = try await Connection.makeConnected()
        let disconnectTime = ContinuousClock.now
        connection.server.disconnect()
        await connection.expectClientEvent(.disconnected)
        await connection.server.acceptConnection()
        await connection.expectClientEvent(.connected)
        #expect(disconnectTime.duration(to: .now) >= .milliseconds(400))
        connection.client.stop()
    }

    @Test
    func reconnectWhenServerStartsLater() async throws {
        let unavailableServer = try WebSocketServerMock()
        let url = await unavailableServer.url()
        unavailableServer.stop()
        let delegate = Delegate()
        let client = WebSocketClient(url: url, loopback: true)
        client.delegate = delegate
        client.start()
        try await Task.sleep(for: .milliseconds(700))
        #expect(!client.isConnected())
        let server = try WebSocketServerMock(port: UInt16(url.port!))
        _ = await server.url()
        await server.acceptConnection()
        let event = await delegate.events.get()
        #expect(event == .connected)
        #expect(client.isConnected())
        client.stop()
    }

    @Test
    func restart() async throws {
        let connection = try await Connection.makeConnected()
        connection.client.stop()
        #expect(!connection.client.isConnected())
        connection.client.start()
        await connection.server.acceptConnection()
        await connection.expectClientEvent(.connected)
        #expect(connection.client.isConnected())
        connection.client.stop()
    }
}
