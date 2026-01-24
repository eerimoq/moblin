import Foundation
import Network

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
                        guard let data, let req = String(bytes: data, encoding: .utf8) else {
                            conn.cancel()
                            return
                        }
                        if req.contains("GET /volleyball.png") {
                            self.serveFile(on: conn, name: "volleyball", ext: "png", type: "image/png")
                        } else if req.contains("GET /remote") {
                            self.serveFile(on: conn, name: "remote", ext: "html", type: "text/html")
                        } else {
                            self.serveFile(on: conn, name: "scoreboard", ext: "html", type: "text/html")
                        }
                    }
                }
            }
            conn.start(queue: .main)
        }
        httpListener?.start(queue: .main)
    }

    private func serveFile(on conn: NWConnection, name: String, ext: String, type: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext),
              let content = try? Data(contentsOf: url)
        else {
            conn.cancel()
            return
        }
        let resp = """
        HTTP/1.1 200 OK\r\n\
        Content-Type: \(type); charset=utf-8\r\n\
        Content-Length: \(content.count)\r\n\
        Connection: close\r\n\
        \r\n
        """
        conn.send(content: resp.utf8Data + content, completion: .contentProcessed { _ in
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
