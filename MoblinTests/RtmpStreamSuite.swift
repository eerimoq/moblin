import AVFoundation
@testable import Moblin
import Testing

private let rtmpQueue = DispatchQueue(label: "test")

private class ModelMock {
    private let status = MessageQueue<String>()
    private let connected = MessageQueue<Void>()

    func waitForStatus() async -> String {
        await status.get()
    }

    func waitForConnected() async {
        await connected.get()
    }
}

extension ModelMock: RtmpStreamDelegate {
    func rtmpStreamStatus(_: RtmpStream, code: String) {
        logger.info("rtmp-test: Status \(code)")
        status.put(code)
    }

    func rtmpStreamConnected(_: RtmpStream) {
        logger.info("rtmp-test: Connected")
        connected.put(())
    }
}

extension ModelMock: ProcessorDelegate {
    func streamAudioLevel(
        audioLevel _: Float,
        numberOfAudioChannels _: Int,
        sampleRate _: Double
    ) {}

    func streamLowFpsImage(lowFpsImage _: Data?, frameNumber _: UInt64) {}

    func streamVideoAttachCameraError() {}

    func streamVideoCaptureSessionError(_: String) {}

    func streamVideoBufferedVideoReady(cameraId _: UUID) {}

    func streamVideoBufferedVideoRemoved(cameraId _: UUID) {}

    func streamVideoFps(fps _: Int) {}

    func streamVideoEncoderResolution(resolution _: CGSize) {}

    func streamRecorderInitSegment(data _: Data) {}

    func streamRecorderDataSegment(segment _: Moblin.RecorderDataSegment) {}

    func streamRecorderFinished() {}

    func streamAudio(sampleBuffer _: CMSampleBuffer) {}

    func streamNoTorch() {}

    func streamSetZoomX(x _: Float) {}

    func streamSetExposureBias(bias _: Float) {}

    func streamSelectedFps(auto _: Bool) {}
}

private actor RtmpServerMock {
    private let listener: NWListener
    private var client: NWConnection?
    private var requestedInputCount: Int?
    private var inputData = Data()
    private let input = MessageQueue<Data>()
    private let localPort = MessageQueue<UInt16>()

    init() throws {
        let parameters = NWParameters(tls: nil)
        parameters.allowLocalEndpointReuse = true
        listener = try NWListener(using: parameters)
        listener.stateUpdateHandler = { state in
            Task {
                await self.handleStateUpdateHandler(state: state)
            }
        }
        listener.newConnectionHandler = { connection in
            Task {
                await self.handlenNewConnectionHandler(connection: connection)
            }
        }
        listener.start(queue: .main)
    }

    func getLocalPort() async -> UInt16 {
        await localPort.get()
    }

    func receive(count: Int) async -> Data {
        requestedInputCount = count
        if let data = tryGetData() {
            return data
        }
        return await input.get()
    }

    func send(chunk: RtmpChunk) {
        for chunk in chunk.split(maximumSize: 128) {
            send(data: chunk)
        }
    }

    func send(data: Data) {
        client!.send(content: data, completion: .idempotent)
    }

    func handleStateUpdateHandler(state: NWListener.State) {
        if state == .ready {
            localPort.put(listener.port!.rawValue)
        }
    }

    func handlenNewConnectionHandler(connection: NWConnection) async {
        client = connection
        connection.start(queue: .main)
        handleData(data: Data())
    }

    private func handleData(data: Data?) {
        guard let data else {
            return
        }
        inputData += data
        if let data = tryGetData() {
            input.put(data)
        }
        client?.receive(minimumIncompleteLength: 1, maximumLength: 4096) { content, _, _, _ in
            Task {
                await self.handleData(data: content)
            }
        }
    }

    private func tryGetData() -> Data? {
        guard let requestedInputCount, inputData.count >= requestedInputCount else {
            return nil
        }
        let data = inputData.subdata(in: 0 ..< requestedInputCount)
        inputData = inputData.advanced(by: requestedInputCount)
        self.requestedInputCount = nil
        return data
    }
}

struct RtmpStreamSuite {
    @Test
    func basic() async throws {
        let streamKey = "5"
        let modelMock = ModelMock()
        let processor = Processor(delegate: modelMock)
        let server = try RtmpServerMock()
        let rtmpStream = RtmpStream(name: "test",
                                    processor: processor,
                                    delegate: modelMock,
                                    queue: rtmpQueue)
        await rtmpStream.setUrl("rtmp://127.0.0.1:\(server.getLocalPort())/live/\(streamKey)")
        rtmpStream.connect()
        let c0c1 = await receiveC0C1(server: server)
        #expect(c0c1[0] == RtmpHandshake.protocolVersion)
        await sendS0S1(server: server)
        _ = await receiveC2(server: server)
        await sendS2(server: server)
        try await expectConnectCommandMessage(server: server)
        await sendWindowAcknowledgementSize(server: server, chunkStreamId: 3, size: 256)
        await sendSetPeerBandwidth(server: server, chunkStreamId: 3, size: 1000)
        try await expectWindowAcknowledgementSize(server: server)
        await server.send(chunk: RtmpChunk(
            type: .zero,
            chunkStreamId: 3,
            message: RtmpCommandMessage(
                streamId: 0,
                transactionId: 2,
                commandType: .amf0Command,
                commandName: .result,
                commandObject: nil,
                arguments: [
                    .object([
                        "level": .string("status"),
                        "code": .string("NetConnection.Connect.Success"),
                        "description": .string("Connection succeeded."),
                    ]),
                ]
            )
        ))
        let setChunkSize = try await receiveSetChunkSize(server: server)
        #expect(setChunkSize.size == 8192)
        #expect(await modelMock.waitForStatus() == "NetConnection.Connect.Success")
        var message = try await receiveCommandMessage(server: server, size: 42)
        #expect(message.commandName == .releaseStream)
        #expect(message.arguments.count == 1)
        #expect(message.arguments[0] == .string(streamKey))
        message = try await receiveCommandMessage(server: server, size: 38)
        #expect(message.commandName == .fcPublish)
        #expect(message.arguments.count == 1)
        #expect(message.arguments[0] == .string(streamKey))
        message = try await receiveCommandMessage(server: server, size: 37)
        #expect(message.commandName == .createStream)
        #expect(message.arguments.count == 0)
        await server.send(chunk: RtmpChunk(
            type: .zero,
            chunkStreamId: 3,
            message: RtmpCommandMessage(
                streamId: 0,
                transactionId: message.transactionId,
                commandType: .amf0Command,
                commandName: .result,
                commandObject: nil,
                arguments: [.number(1)]
            )
        ))
        message = try await receiveCommandMessage(server: server, size: 43)
        #expect(message.commandName == .publish)
        #expect(message.arguments.count == 2)
        #expect(message.arguments[0] == .string(streamKey))
        #expect(message.arguments[1] == .string("live"))
        await server.send(chunk: RtmpChunk(
            type: .zero,
            chunkStreamId: 3,
            message: RtmpCommandMessage(
                streamId: 0,
                transactionId: message.transactionId,
                commandType: .amf0Command,
                commandName: .onStatus,
                commandObject: nil,
                arguments: [
                    .object([
                        "level": .string("status"),
                        "code": .string("NetStream.Publish.Start"),
                        "description": .string("Start publishing."),
                    ]),
                ]
            )
        ))
        #expect(await modelMock.waitForStatus() == "NetStream.Publish.Start")
        await modelMock.waitForConnected()
        rtmpStream.disconnect()
        // @setDataFrame
        _ = await server.receive(count: 192)
        message = try await receiveCommandMessage(server: server, size: 40)
        #expect(message.commandName == .fcUnpublish)
        #expect(message.arguments.count == 1)
        #expect(message.arguments[0] == .string(streamKey))
        message = try await receiveCommandMessage(server: server, size: 46)
        #expect(message.commandName == .deleteStream)
        #expect(message.arguments.count == 1)
        #expect(message.arguments[0] == .number(1))
        message = try await receiveCommandMessage(server: server, size: 45)
        #expect(message.commandName == .closeStream)
        #expect(message.arguments.count == 1)
        #expect(message.arguments[0] == .number(1))
    }

    @Test
    func youTube() async throws {
        let streamKey = "5"
        let modelMock = ModelMock()
        let processor = Processor(delegate: modelMock)
        let server = try RtmpServerMock()
        let rtmpStream = RtmpStream(name: "test",
                                    processor: processor,
                                    delegate: modelMock,
                                    queue: rtmpQueue)
        await rtmpStream.setUrl("rtmp://127.0.0.1:\(server.getLocalPort())/live/\(streamKey)")
        rtmpStream.connect()
        let c0c1 = await receiveC0C1(server: server)
        #expect(c0c1[0] == RtmpHandshake.protocolVersion)
        await sendS0S1(server: server)
        _ = await receiveC2(server: server)
        await sendS2(server: server)
        try await expectConnectCommandMessage(server: server)
        await sendWindowAcknowledgementSize(server: server, chunkStreamId: 2, size: 2_500_000)
        await sendSetPeerBandwidth(server: server, chunkStreamId: 2, size: 59_768_832)
        try await expectWindowAcknowledgementSize(server: server)
        await server.send(chunk: RtmpChunk(
            type: .zero,
            chunkStreamId: 3,
            message: RtmpCommandMessage(
                streamId: 0,
                transactionId: 2,
                commandType: .amf0Command,
                commandName: .result,
                commandObject: [
                    "fmsVer": .string("FMS/3,5,3,824"),
                    "capabilities": .number(127),
                    "mode": .number(1),
                ],
                arguments: [
                    .object([
                        "level": .string("status"),
                        "code": .string("NetConnection.Connect.Success"),
                        "description": .string("Connection succeeded."),
                        "objectEncoding": .number(0),
                    ]),
                ]
            )
        ))
        // Nothing below is updated to match Wireshark.
        let setChunkSize = try await receiveSetChunkSize(server: server)
        #expect(setChunkSize.size == 8192)
        #expect(await modelMock.waitForStatus() == "NetConnection.Connect.Success")
        var message = try await receiveCommandMessage(server: server, size: 42)
        #expect(message.commandName == .releaseStream)
        #expect(message.arguments.count == 1)
        #expect(message.arguments[0] == .string(streamKey))
        message = try await receiveCommandMessage(server: server, size: 38)
        #expect(message.commandName == .fcPublish)
        #expect(message.arguments.count == 1)
        #expect(message.arguments[0] == .string(streamKey))
        message = try await receiveCommandMessage(server: server, size: 37)
        #expect(message.commandName == .createStream)
        #expect(message.arguments.count == 0)
        await server.send(chunk: RtmpChunk(
            type: .zero,
            chunkStreamId: 3,
            message: RtmpCommandMessage(
                streamId: 0,
                transactionId: message.transactionId,
                commandType: .amf0Command,
                commandName: .result,
                commandObject: nil,
                arguments: [.number(1)]
            )
        ))
        message = try await receiveCommandMessage(server: server, size: 43)
        #expect(message.commandName == .publish)
        #expect(message.arguments.count == 2)
        #expect(message.arguments[0] == .string(streamKey))
        #expect(message.arguments[1] == .string("live"))
        await server.send(chunk: RtmpChunk(
            type: .zero,
            chunkStreamId: 3,
            message: RtmpCommandMessage(
                streamId: 0,
                transactionId: message.transactionId,
                commandType: .amf0Command,
                commandName: .onStatus,
                commandObject: nil,
                arguments: [
                    .object([
                        "level": .string("status"),
                        "code": .string("NetStream.Publish.Start"),
                        "description": .string("Start publishing."),
                    ]),
                ]
            )
        ))
        #expect(await modelMock.waitForStatus() == "NetStream.Publish.Start")
        await modelMock.waitForConnected()
        rtmpStream.disconnect()
        // @setDataFrame
        _ = await server.receive(count: 192)
        message = try await receiveCommandMessage(server: server, size: 40)
        #expect(message.commandName == .fcUnpublish)
        #expect(message.arguments.count == 1)
        #expect(message.arguments[0] == .string(streamKey))
        message = try await receiveCommandMessage(server: server, size: 46)
        #expect(message.commandName == .deleteStream)
        #expect(message.arguments.count == 1)
        #expect(message.arguments[0] == .number(1))
        message = try await receiveCommandMessage(server: server, size: 45)
        #expect(message.commandName == .closeStream)
        #expect(message.arguments.count == 1)
        #expect(message.arguments[0] == .number(1))
    }

    @Test
    func acknowledgementChunkSplitOverTwoReads() {
        let modelMock = ModelMock()
        let processor = Processor(delegate: modelMock)
        let rtmpStream = RtmpStream(name: "test",
                                    processor: processor,
                                    delegate: modelMock,
                                    queue: rtmpQueue)
        let connection = RtmpConnection(name: "test", queue: rtmpQueue)
        connection.stream = rtmpStream
        rtmpStream.info.onWritten(sequence: 14000)
        #expect(rtmpStream.info.stats.value.packetsInFlight == 10)
        let typeZeroChunk = Data([0x02, 0, 0, 0, 0, 0, 4, 0x03, 0, 0, 0, 0]) + UInt32(1).bigEndian.data
        #expect(connection.socketDataReceived(data: typeZeroChunk).isEmpty)
        #expect(rtmpStream.info.stats.value.packetsInFlight == 10)
        let typeThreeChunk = Data([0xC2]) + UInt32(14001).bigEndian.data
        let buffered = connection.socketDataReceived(data: typeThreeChunk.prefix(3))
        #expect(buffered == typeThreeChunk.prefix(3))
        #expect(connection.socketDataReceived(data: buffered + typeThreeChunk.suffix(2)).isEmpty)
        #expect(rtmpStream.info.stats.value.packetsInFlight == 0)
    }

    @Test
    func typeZeroChunk() throws {
        let data = Data([0x04, 0x01, 0x02, 0x03, 0, 0, 5, 0x08, 9, 0, 0, 0]) + Data([1, 2, 3, 4, 5])
        let message = try #require(readMessage(data: data))
        #expect(message.type == .audio)
        #expect(message.timestamp == 0x010203)
        #expect(message.length == 5)
        #expect(message.streamId == 9)
        #expect(message.encoded == Data([1, 2, 3, 4, 5]))
    }

    @Test
    func typeZeroChunkWithExtendedTimestamp() throws {
        let header = Data([0x04, 0xFF, 0xFF, 0xFF, 0, 0, 1, 0x08, 9, 0, 0, 0])
        let message = try #require(readMessage(data: header + Data([1, 2, 3, 4]) + Data([7])))
        #expect(message.timestamp == 0x0102_0304)
        #expect(message.encoded == Data([7]))
    }

    @Test
    func typeOneChunk() throws {
        let typeZero = Data([0x05, 0, 0, 100, 0, 0, 4, 0x03, 7, 0, 0, 0]) + UInt32(1).bigEndian.data
        let typeOne = Data([0x45, 0, 0, 20, 0, 0, 8, 0x08]) + Data([1, 2, 3, 4, 5, 6, 7, 8])
        let messages = readMessages(data: typeZero + typeOne)
        #expect(messages.count == 2)
        let message = try #require(messages.last)
        #expect(message.type == .audio)
        #expect(message.timestamp == 120)
        #expect(message.length == 8)
        #expect(message.streamId == 7)
        #expect(message.encoded == Data([1, 2, 3, 4, 5, 6, 7, 8]))
    }

    @Test
    func typeTwoChunk() throws {
        let typeZero = Data([0x06, 0, 0, 50, 0, 0, 8, 0x08, 3, 0, 0, 0]) + Data([1, 2, 3, 4, 5, 6, 7, 8])
        let typeTwo = Data([0x86, 0, 0, 7]) + Data([9, 10, 11, 12, 13, 14, 15, 16])
        let messages = readMessages(data: typeZero + typeTwo)
        #expect(messages.count == 2)
        let message = try #require(messages.last)
        #expect(message.type == .audio)
        #expect(message.timestamp == 57)
        #expect(message.length == 8)
        #expect(message.streamId == 3)
        #expect(message.encoded == Data([9, 10, 11, 12, 13, 14, 15, 16]))
    }

    @Test
    func typeThreeChunkStartsNewMessage() {
        var data = Data([0x02, 0, 0, 10, 0, 0, 4, 0x03, 0, 0, 0, 0]) + UInt32(1).bigEndian.data
        data += Data([0x82, 0, 0, 5]) + UInt32(2).bigEndian.data
        data += Data([0xC2]) + UInt32(3).bigEndian.data
        let messages = readMessages(data: data).compactMap { $0 as? RtmpAcknowledgementMessage }
        #expect(messages.map(\.sequence) == [1, 2, 3])
        #expect(messages.map(\.timestamp) == [10, 15, 20])
    }

    @Test
    func twoByteBasicHeader() {
        #expect(RtmpChunkType.zero.toBasicHeader(200) == Data([0x00, 0x88]))
        var data = Data([0x02, 0, 0, 10, 0, 0, 4, 0x03, 0, 0, 0, 0]) + UInt32(1).bigEndian.data
        data += Data([0x00, 0x02, 0, 0, 20, 0, 0, 8, 0x08, 0, 0, 0, 0]) + Data([1, 2, 3, 4, 5, 6, 7, 8])
        data += Data([0xC2]) + UInt32(2).bigEndian.data
        data += Data([0xC0, 0x02]) + Data([9, 10, 11, 12, 13, 14, 15, 16])
        let messages = readMessages(data: data)
        #expect(messages.map(\.type) == [.ack, .audio, .ack, .audio])
        #expect(messages.map(\.length) == [4, 8, 4, 8])
        #expect(messages.last?.encoded == Data([9, 10, 11, 12, 13, 14, 15, 16]))
    }

    @Test
    func threeByteBasicHeader() {
        #expect(RtmpChunkType.zero.toBasicHeader(400) == Data([0x01, 0x50, 0x01]))
        var data = Data([0x01, 0x02, 0x00, 0, 0, 10, 0, 0, 4, 0x03, 0, 0, 0, 0])
        data += UInt32(1).bigEndian.data
        data += Data([0xC0, 0x02]) + UInt32(2).bigEndian.data
        let messages = readMessages(data: data).compactMap { $0 as? RtmpAcknowledgementMessage }
        #expect(messages.map(\.sequence) == [1, 2])
    }

    @Test
    func typeThreeChunkContinuesMessage() throws {
        let payload = Data((0 ..< 300).map { UInt8($0 % 251) })
        var data = Data([0x08, 0, 0, 0, 0, 1, 0x2C, 0x08, 1, 0, 0, 0]) + payload.prefix(128)
        data += Data([0xC8]) + payload[128 ..< 256]
        data += Data([0xC8]) + payload[256 ..< 300]
        let message = try #require(readMessage(data: data))
        #expect(message.type == .audio)
        #expect(message.streamId == 1)
        #expect(message.length == 300)
        #expect(message.encoded == payload)
    }

    @Test
    func typeThreeChunkContinuesMessageWithExtendedTimestamp() throws {
        let payload = Data((0 ..< 300).map { UInt8($0 % 251) })
        var data = Data([0x08, 0xFF, 0xFF, 0xFF, 0, 1, 0x2C, 0x08, 1, 0, 0, 0])
        data += UInt32(0x0100_0000).bigEndian.data + payload.prefix(128)
        data += Data([0xC8]) + UInt32(0x0100_0000).bigEndian.data + payload[128 ..< 256]
        data += Data([0xC8]) + UInt32(0x0100_0000).bigEndian.data + payload[256 ..< 300]
        let message = try #require(readMessage(data: data))
        #expect(message.type == .audio)
        #expect(message.timestamp == 0x0100_0000)
        #expect(message.length == 300)
        #expect(message.encoded == payload)
    }

    @Test
    func typeThreeChunkStartsNewMessageWithExtendedTimestamp() {
        var data = Data([0x02, 0, 0, 10, 0, 0, 4, 0x03, 0, 0, 0, 0]) + UInt32(1).bigEndian.data
        data += Data([0x82, 0xFF, 0xFF, 0xFF]) + UInt32(0x0100_0000).bigEndian.data
        data += UInt32(2).bigEndian.data
        data += Data([0xC2]) + UInt32(0x0100_0000).bigEndian.data + UInt32(3).bigEndian.data
        let messages = readMessages(data: data).compactMap { $0 as? RtmpAcknowledgementMessage }
        #expect(messages.map(\.sequence) == [1, 2, 3])
        #expect(messages.map(\.timestamp) == [10, 0x0100_000A, 0x0200_000A])
    }

    @Test
    func splitAndReadMessageWithExtendedTimestamp() throws {
        let payload = Data((0 ..< 300).map { UInt8($0 % 251) })
        let chunk = RtmpChunk(type: .zero,
                              chunkStreamId: 8,
                              message: RtmpAudioMessage(streamId: 1,
                                                        timestamp: 0xFFFFFF,
                                                        payload: payload))
        let message = try #require(readMessage(data: Data(chunk.split(maximumSize: 128).joined())))
        #expect(message.type == .audio)
        #expect(message.timestamp == 0xFFFFFF)
        #expect(message.streamId == 1)
        #expect(message.encoded == payload)
    }

    @Test
    func chunksDeliveredOneByteAtATime() {
        let reader = RtmpChunkReader()
        var data = Data([0x02, 0, 0, 10, 0, 0, 4, 0x03, 0, 0, 0, 0]) + UInt32(1).bigEndian.data
        data += Data([0x00, 0x02, 0, 0, 10, 0, 0, 4, 0x03, 0, 0, 0, 0]) + UInt32(2).bigEndian.data
        data += Data([0x01, 0x02, 0x01, 0, 0, 10, 0, 0, 4, 0x03, 0, 0, 0, 0]) + UInt32(3).bigEndian.data
        var messages: [RtmpMessage] = []
        var buffer = Data()
        for byte in data {
            buffer.append(byte)
            buffer = reader.read(data: buffer) { messages.append($0) }
        }
        #expect(buffer.isEmpty)
        #expect(messages.compactMap { ($0 as? RtmpAcknowledgementMessage)?.sequence } == [1, 2, 3])
    }
}

private func receiveC0C1(server: RtmpServerMock) async -> Data {
    await server.receive(count: RtmpHandshake.sigSize + 1)
}

private func sendS0S1(server: RtmpServerMock) async {
    await server.send(data: Data(count: RtmpHandshake.sigSize + 1))
}

private func receiveC2(server: RtmpServerMock) async -> Data {
    await server.receive(count: RtmpHandshake.sigSize)
}

private func sendS2(server: RtmpServerMock) async {
    await server.send(data: Data(count: RtmpHandshake.sigSize))
}

private func sendWindowAcknowledgementSize(server: RtmpServerMock, chunkStreamId: UInt16,
                                           size: UInt32) async
{
    await server.send(chunk: RtmpChunk(
        type: .zero,
        chunkStreamId: chunkStreamId,
        message: RtmpWindowAcknowledgementSizeMessage(size)
    ))
}

private func sendSetPeerBandwidth(server: RtmpServerMock, chunkStreamId: UInt16, size: UInt32) async {
    await server.send(chunk: RtmpChunk(
        type: .zero,
        chunkStreamId: chunkStreamId,
        message: RtmpSetPeerBandwidthMessage(size: size, limit: .dynamic)
    ))
}

private func expectConnectCommandMessage(server: RtmpServerMock) async throws {
    let data = await server.receive(count: 273)
    #expect(data[0] == 0x03)
    let message = try #require(readMessage(data: data) as? RtmpCommandMessage)
    #expect(message.commandName == .connect)
    #expect(message.transactionId == 1)
    guard let connectMessage = message.commandObject else {
        throw "error"
    }
    #expect(connectMessage["app"] == .string("live"))
    #expect(connectMessage["flashVer"] == .string("FMLE/3.0 (compatible; FMSc/1.0)"))
    #expect(connectMessage["swfUrl"] == .null)
    guard case let .string(tcUrl) = connectMessage["tcUrl"] else {
        throw "error"
    }
    #expect(tcUrl.wholeMatch(of: /rtmp:\/\/127\.0\.0\.1:\d+\/live/) != nil)
    #expect(connectMessage["fpad"] == .bool(false))
    #expect(connectMessage["capabilities"] == .number(239))
    #expect(connectMessage["audioCodecs"] == .number(0x0400))
    #expect(connectMessage["videoCodecs"] == .number(0x0080))
    #expect(connectMessage["videoFunction"] == .number(1))
    #expect(connectMessage["pageUrl"] == .null)
    #expect(connectMessage["objectEncoding"] == .number(0))
}

private func expectWindowAcknowledgementSize(server: RtmpServerMock) async throws {
    let data = await server.receive(count: 16)
    #expect(data[0] == 0x02)
    let message = try #require(readMessage(data: data) as? RtmpWindowAcknowledgementSizeMessage)
    #expect(message.size == 100_000)
}

private func receiveCommandMessage(server: RtmpServerMock, size: Int) async throws -> RtmpCommandMessage {
    let data = await server.receive(count: size)
    return try #require(readMessage(data: data) as? RtmpCommandMessage)
}

private func receiveSetChunkSize(server: RtmpServerMock) async throws -> RtmpSetChunkSizeMessage {
    let data = await server.receive(count: 16)
    return try #require(readMessage(data: data) as? RtmpSetChunkSizeMessage)
}

private func readMessages(data: Data) -> [RtmpMessage] {
    var messages: [RtmpMessage] = []
    let remaining = RtmpChunkReader().read(data: data) { messages.append($0) }
    #expect(remaining.isEmpty)
    return messages
}

private func readMessage(data: Data) -> RtmpMessage? {
    let messages = readMessages(data: data)
    #expect(messages.count == 1)
    return messages.first
}
