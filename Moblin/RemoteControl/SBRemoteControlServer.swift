import Foundation
import Network
import UIKit

class SBRemoteControlServer {
    private var httpListener: NWListener?
    private var wsListener: NWListener?
    private var connectedClients: [NWConnection] = []
    var onMessageReceived: ((SBMessage) -> Void)?
    var onClientConnected: ((NWConnection) -> Void)?

    func start() {
        startHttpServer()
        startWsServer()
    }

    private func startHttpServer() {
        httpListener = try? NWListener(using: .tcp, on: 8080)
        httpListener?.newConnectionHandler = { conn in
            conn.stateUpdateHandler = { state in
                if case .ready = state {
                    conn.receive(minimumIncompleteLength: 1, maximumLength: 1024) { data, _, _, _ in
                        guard data != nil else {
                            conn.cancel()
                            return
                        }
                        self.serveFile(on: conn, name: "remote", ext: "html", type: "text/html")
                    }
                }
            }
            conn.start(queue: .main)
        }
        httpListener?.start(queue: .main)
    }

    private func serveFile(on conn: NWConnection, name: String, ext: String, type: String) {
        let path = Bundle.main.path(forResource: name, ofType: ext, inDirectory: "Web")
            ?? Bundle.main.path(forResource: name, ofType: ext)
        guard let path = path, let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            conn.cancel()
            return
        }
        let resp = """
        HTTP/1.1 200 OK\r\nContent-Type: \(type); charset=utf-8\r\n\
        Content-Length: \(content.utf8.count)\r\n\
        Connection: close\r\n\
        \r\n\
        \(content)
        """
        conn.send(content: resp.data(using: .utf8), completion: .contentProcessed { _ in
            conn.cancel()
        })
    }

    private func startWsServer() {
        let params = NWParameters.tcp
        params.defaultProtocolStack.applicationProtocols.insert(NWProtocolWebSocket.Options(), at: 0)
        try? wsListener = NWListener(using: params, on: 8081)
        wsListener?.newConnectionHandler = { conn in
            conn.stateUpdateHandler = { state in
                if case .ready = state {
                    self.connectedClients.append(conn)
                    self.onClientConnected?(conn)
                    self.receiveWs(on: conn)
                }
            }
            conn.start(queue: .main)
        }
        wsListener?.start(queue: .main)
    }

    private func receiveWs(on conn: NWConnection) {
        conn.receiveMessage { content, _, _, err in
            if let d = content, let msg = try? JSONDecoder().decode(SBMessage.self, from: d) {
                DispatchQueue.main.async { self.onMessageReceived?(msg) }
            }
            if err == nil {
                self.receiveWs(on: conn)
            } else {
                self.connectedClients.removeAll(where: { $0 === conn })
            }
        }
    }

    func broadcastMessageString(_ message: String) {
        for client in connectedClients {
            sendMessageString(connection: client, message: message)
        }
    }

    func sendMessageString(connection: NWConnection, message: String) {
        connection.sendWebSocket(data: message.data(using: .utf8), opcode: .text)
    }
}
