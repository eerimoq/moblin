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
        do {
            httpListener = try NWListener(using: .tcp, on: 8080)
            httpListener?.newConnectionHandler = { conn in
                conn.stateUpdateHandler = { state in
                    if case .ready = state {
                        conn.receive(minimumIncompleteLength: 1, maximumLength: 1024) { data, _, _, _ in
                            guard let data = data, let req = String(data: data, encoding: .utf8) else {
                                conn.cancel()
                                return
                            }
                            if req.contains("GET /volleyball.png") {
                                self.serveIcon(on: conn)
                            } else if req.contains("GET /scoreboard") {
                                self.serveFile(
                                    on: conn,
                                    name: "scoreboard",
                                    ext: "html",
                                    type: "text/html"
                                )
                            } else {
                                self.serveFile(on: conn, name: "remote", ext: "html", type: "text/html")
                            }
                        }
                    }
                }
                conn.start(queue: .main)
            }
            httpListener?.start(queue: .main)
        } catch {
            logger.info("SB Server: HTTP Error")
        }
    }

    private func serveFile(on conn: NWConnection, name: String, ext: String, type: String) {
        let path = Bundle.main.path(forResource: name, ofType: ext, inDirectory: "Web")
            ?? Bundle.main.path(forResource: name, ofType: ext)
        guard let path = path, let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            conn.cancel()
            return
        }
        let resp = "HTTP/1.1 200 OK\r\nContent-Type: \(type); charset=utf-8\r\nContent-Length: \(content.utf8.count)\r\nConnection: close\r\n\r\n\(content)"
        conn.send(content: resp.data(using: .utf8), completion: .contentProcessed { _ in
            conn.cancel()
        })
    }

    private func serveIcon(on conn: NWConnection) {
        guard let img = UIImage(named: "VolleyballIndicator"),
              let data = img.pngData()
        else {
            conn.cancel()
            return
        }
        let head = "HTTP/1.1 200 OK\r\nContent-Type: image/png\r\nContent-Length: \(data.count)\r\nConnection: close\r\n\r\n"
        var out = Data(head.utf8); out.append(data)
        conn.send(content: out, completion: .contentProcessed { _ in
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
                    self.connectedClients.append(conn); self.onClientConnected?(conn); self
                        .receiveWs(on: conn)
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
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "text", metadata: [metadata])
        connection.send(
            content: message.data(using: .utf8),
            contentContext: context,
            isComplete: true,
            completion: .idempotent
        )
    }
}
