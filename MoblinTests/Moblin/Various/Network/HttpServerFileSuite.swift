import Foundation
@testable import Moblin
import Network
import Testing

@MainActor
private class HttpFileServer {
    private let listener: NWListener
    private let server: HttpServer

    init(fileUrl: URL) throws {
        listener = try NWListener(using: .tcp)
        server = HttpServer(queue: .main, routes: [
            HttpServerRoute(path: "/recording.mp4") { _, response in
                #expect(Thread.isMainThread)
                response.sendFile(url: fileUrl,
                                  contentType: "video/mp4",
                                  headers: [.init(name: "Content-Disposition",
                                                  value: "attachment; filename=recording.mp4")])
            },
        ])
        listener.newConnectionHandler = { [server] connection in
            connection.start(queue: .main)
            HttpServerConnection(connection: connection, server: server, queue: .main).receiveData()
        }
    }

    func start() async throws -> URL {
        let port: NWEndpoint.Port = try await withCheckedThrowingContinuation { continuation in
            listener.stateUpdateHandler = { [listener] state in
                switch state {
                case .ready:
                    listener.stateUpdateHandler = nil
                    continuation.resume(returning: listener.port!)
                case let .failed(error):
                    listener.stateUpdateHandler = nil
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            listener.start(queue: .main)
        }
        return URL(string: "http://127.0.0.1:\(port.rawValue)/recording.mp4")!
    }

    func stop() {
        listener.cancel()
    }
}

struct HttpServerFileSuite {
    @Test(arguments: [0, 512 * 1024 + 97])
    @MainActor
    func fileResponse(size: Int) async throws {
        let fileUrl = FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
        let expected = Data((0 ..< size).map { UInt8(truncatingIfNeeded: $0) })
        try expected.write(to: fileUrl)
        defer { try? FileManager.default.removeItem(at: fileUrl) }
        let server = try HttpFileServer(fileUrl: fileUrl)
        defer { server.stop() }
        let url = try await server.start()
        let (data, response) = try await URLSession.shared.data(from: url)
        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 200)
        #expect(httpResponse.value(forHTTPHeaderField: "Content-Length") == String(size))
        #expect(httpResponse.value(forHTTPHeaderField: "Content-Type") == "video/mp4")
        #expect(httpResponse.value(forHTTPHeaderField: "Content-Disposition") ==
            "attachment; filename=recording.mp4")
        #expect(data == expected)
    }

    @Test
    @MainActor
    func missingFileResponse() async throws {
        let fileUrl = FileManager.default.temporaryDirectory.appending(component: UUID().uuidString)
        let server = try HttpFileServer(fileUrl: fileUrl)
        defer { server.stop() }
        let url = try await server.start()
        let (data, response) = try await URLSession.shared.data(from: url)
        let httpResponse = try #require(response as? HTTPURLResponse)
        #expect(httpResponse.statusCode == 404)
        #expect(httpResponse.value(forHTTPHeaderField: "Content-Length") == "0")
        #expect(data.isEmpty)
    }
}
