import CoreMedia
import Foundation
@testable import Moblin
import Network
import Testing

private enum Insta360TestEvent: Sendable {
    case ready(UInt16)
    case state(Insta360ClientState)
    case picture(width: Int32, height: Int32)
    case stopped
    case failed(String)
}

private enum Insta360TestError: Error {
    case timeout
    case connection(String)
}

private class Insta360TestCamera: Insta360ClientDelegate, @unchecked Sendable {
    let events: AsyncStream<Insta360TestEvent>
    private let continuation: AsyncStream<Insta360TestEvent>.Continuation
    private let queue = DispatchQueue(label: "insta360-test-camera")
    private let listener: NWListener
    private var connection: NWConnection?
    private var buffer = Data()

    init() throws {
        (events, continuation) = AsyncStream.makeStream()
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        listener = try NWListener(using: parameters)
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else {
                return
            }
            switch state {
            case .ready:
                if let port = listener.port {
                    continuation.yield(.ready(port.rawValue))
                }
            case let .failed(error):
                continuation.yield(.failed(error.localizedDescription))
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else {
                return
            }
            self.connection = connection
            connection.start(queue: queue)
            receive(connection)
        }
        listener.start(queue: queue)
    }

    func stop() {
        queue.async {
            self.connection?.cancel()
            self.listener.cancel()
            self.continuation.finish()
        }
    }

    func insta360Client(_: Insta360Client, stateChanged state: Insta360ClientState) {
        continuation.yield(.state(state))
    }

    func insta360Client(_: Insta360Client, videoBuffer: CMSampleBuffer) {
        guard let description = videoBuffer.formatDescription else {
            return
        }
        let dimensions = CMVideoFormatDescriptionGetDimensions(description)
        continuation.yield(.picture(width: dimensions.width, height: dimensions.height))
    }

    private func receive(_ connection: NWConnection) {
        connection
            .receive(minimumIncompleteLength: 1,
                     maximumLength: 4096)
            { [weak self] data, _, complete, error in
                guard let self else {
                    return
                }
                if let data {
                    buffer.append(data)
                    consumeCommands(connection)
                }
                if !complete, error == nil {
                    receive(connection)
                }
            }
    }

    private func consumeCommands(_ connection: NWConnection) {
        while buffer.count >= 4 {
            let length = Int(buffer[0]) | Int(buffer[1]) << 8 | Int(buffer[2]) << 16 | Int(buffer[3]) << 24
            guard length >= 7, length <= 4096, buffer.count >= length else {
                return
            }
            let payload = Data(buffer[4 ..< length])
            buffer = Data(buffer.dropFirst(length))
            if payload.starts(with: [6, 0, 0]) {
                connection.send(content: Data([17, 0, 0, 0, 6, 0, 0]) + Data("syNceNdinS".utf8),
                                completion: .idempotent)
            } else if payload.count >= 12, payload.starts(with: [4, 0, 0]) {
                if payload[3] == 1 {
                    sendPreview(connection)
                } else if payload[3] == 2 {
                    continuation.yield(.stopped)
                }
            }
        }
    }

    private func sendPreview(_ connection: NWConnection) {
        let encodedPicture = Data(base64Encoded:
            "AAAAAUABDAH//wQIAAADAJ+oAAADAAAeugJAAAAAAUIBAQQIAAADAJ+oAAADAAAeoCCBBZbqSTK8BaAg"
                + "AAADACAAAAMDwQAAAAFEAcFysCJAAAABKAGveOsCAf/2ARoPSZY/es1FR5w=")!
        var video = Data()
        for _ in 0 ..< 5 {
            video.append(encodedPicture)
        }
        var length = UInt32(video.count + 16).littleEndian
        let header = withUnsafeBytes(of: &length) { Data($0) } + Data([1, 0, 0]) + Data(
            repeating: 0,
            count: 9
        )
        let wire = header + video
        connection.send(content: Data(wire.prefix(2)), completion: .idempotent)
        connection.send(content: Data(wire.dropFirst(2).prefix(9)), completion: .idempotent)
        connection.send(content: Data(wire.dropFirst(11)), completion: .idempotent)
    }
}

struct Insta360ClientSuite {
    @Test
    func receivesAndDecodesHevcOverTcpThenStopsTheCameraPreview() async throws {
        let camera = try Insta360TestCamera()
        defer { camera.stop() }
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                var client: Insta360Client?
                defer { client?.stop() }
                var waitingForVideo = false
                var pictures = 0
                for await event in camera.events {
                    switch event {
                    case let .ready(port):
                        client = Insta360Client(cameraId: UUID(), host: "127.0.0.1", port: port, latency: 0.3,
                                                softwareDecoding: false, colorRange: .full, delegate: camera)
                        client?.start()
                    case let .state(state):
                        if state == .waitingForVideo {
                            waitingForVideo = true
                        } else if state == .streaming {
                            #expect(waitingForVideo)
                        }
                    case let .picture(width, height):
                        #expect(width == 64)
                        #expect(height == 64)
                        pictures += 1
                        if pictures == 2 {
                            client?.stop()
                        }
                    case .stopped:
                        #expect(pictures >= 2)
                        return
                    case let .failed(message):
                        throw Insta360TestError.connection(message)
                    }
                }
            }
            group.addTask {
                try await Task.sleep(for: .seconds(10))
                throw Insta360TestError.timeout
            }
            try await group.next()
            group.cancelAll()
        }
    }
}
