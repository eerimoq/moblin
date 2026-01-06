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

    // --- PORT 8080: Serves the Web Pages and the PNG Icon ---
    private func startHttpServer() {
        do {
            let params = NWParameters.tcp
            self.httpListener = try NWListener(using: params, on: 8080)
            
            self.httpListener?.stateUpdateHandler = { state in
                if case .ready = state { logger.info("SB Remote: HTTP Page Server ready on 8080") }
            }
            
            self.httpListener?.newConnectionHandler = { connection in
                connection.stateUpdateHandler = { state in
                    if case .ready = state {
                        connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { data, _, _, _ in
                            guard let data = data, let request = String(data: data, encoding: .utf8) else {
                                connection.cancel(); return
                            }
                            
                            if request.contains("GET /volleyball.png") {
                                self.serveVolleyballIcon(on: connection)
                            } else if request.contains("GET /scoreboard") {
                                self.servePage(on: connection, html: SB_DISPLAY_HTML)
                            } else {
                                self.servePage(on: connection, html: SB_REMOTE_HTML)
                            }
                        }
                    }
                }
                connection.start(queue: .main)
            }
            self.httpListener?.start(queue: .main)
        } catch {
            logger.info("SB Remote: HTTP Start Error")
        }
    }

    private func serveVolleyballIcon(on connection: NWConnection) {
        // Try to load the image from Xcode Assets
        guard let image = UIImage(named: "VolleyballIndicator") else {
            print("❌ SB Remote Error: Asset 'VolleyballIndicator' not found.")
            connection.cancel(); return
        }
        
        guard let data = image.pngData() else {
            print("❌ SB Remote Error: Could not convert asset to PNG data.")
            connection.cancel(); return
        }
        
        // Construct standard binary HTTP response
        let header = "HTTP/1.1 200 OK\r\n" +
                     "Content-Type: image/png\r\n" +
                     "Content-Length: \(data.count)\r\n" +
                     "Connection: close\r\n\r\n"
        
        var responseData = Data(header.utf8)
        responseData.append(data)
        
        connection.send(content: responseData, completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }

    private func servePage(on connection: NWConnection, html: String) {
        let header = "HTTP/1.1 200 OK\r\n" +
                     "Content-Type: text/html; charset=utf-8\r\n" +
                     "Content-Length: \(html.utf8.count)\r\n" +
                     "Connection: close\r\n\r\n"
        
        var responseData = Data(header.utf8)
        responseData.append(Data(html.utf8))
        
        connection.send(content: responseData, completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }

    // --- PORT 8081: Handles the Real-Time WebSocket Data ---
    private func startWsServer() {
        do {
            let params = NWParameters.tcp
            let stack = params.defaultProtocolStack
            stack.applicationProtocols.insert(NWProtocolWebSocket.Options(), at: 0)
            
            self.wsListener = try NWListener(using: params, on: 8081)
            self.wsListener?.newConnectionHandler = { connection in
                connection.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        self.connectedClients.append(connection)
                        self.onClientConnected?(connection)
                        self.receiveWs(on: connection)
                    case .failed, .cancelled:
                        self.connectedClients.removeAll(where: { $0 === connection })
                    default:
                        break
                    }
                }
                connection.start(queue: .main)
            }
            self.wsListener?.start(queue: .main)
        } catch {
            logger.info("SB Remote: WS Start Error")
        }
    }

    private func receiveWs(on connection: NWConnection) {
        connection.receiveMessage { content, _, _, error in
            if let data = content, let message = try? JSONDecoder().decode(SBMessage.self, from: data) {
                DispatchQueue.main.async { self.onMessageReceived?(message) }
            }
            if let error = error {
                self.connectedClients.removeAll(where: { $0 === connection })
                return
            }
            self.receiveWs(on: connection)
        }
    }

    func broadcastMessageString(_ message: String) {
        for client in connectedClients { sendMessageString(connection: client, message: message) }
    }

    func sendMessageString(connection: NWConnection, message: String) {
        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "text", metadata: [metadata])
        connection.send(content: message.data(using: .utf8), contentContext: context, isComplete: true, completion: .contentProcessed({ error in
            if error != nil { self.connectedClients.removeAll(where: { $0 === connection }) }
        }))
    }
}
