import AVFoundation
@testable import Moblin
import Testing

private let rtmpQueue = DispatchQueue(label: "test")

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

    func send(chunk: RtmpChunk, maximumSize: Int = 128) {
        for chunk in chunk.split(maximumSize: maximumSize) {
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
        let modelMock = RtmpModelMock()
        let processor = Processor(
            delegate: modelMock,
            colorRange: .full
        )
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
        let modelMock = RtmpModelMock()
        let processor = Processor(
            delegate: modelMock,
            colorRange: .full
        )
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
        let modelMock = RtmpModelMock()
        let processor = Processor(
            delegate: modelMock,
            colorRange: .full
        )
        let rtmpStream = RtmpStream(name: "test",
                                    processor: processor,
                                    delegate: modelMock,
                                    queue: rtmpQueue)
        rtmpStream.info.onWritten(sequence: 14000)
        #expect(rtmpStream.info.stats.value.packetsInFlight == 10)
        let typeZeroChunk = Data([0x02, 0, 0, 0, 0, 0, 4, 0x03, 0, 0, 0, 0]) + UInt32(1).bigEndian.data
        #expect(rtmpStream.socketDataReceived(data: typeZeroChunk).isEmpty)
        #expect(rtmpStream.info.stats.value.packetsInFlight == 10)
        let typeThreeChunk = Data([0xC2]) + UInt32(14001).bigEndian.data
        let buffered = rtmpStream.socketDataReceived(data: typeThreeChunk.prefix(3))
        #expect(buffered == typeThreeChunk.prefix(3))
        #expect(rtmpStream.socketDataReceived(data: buffered + typeThreeChunk.suffix(2)).isEmpty)
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

private final class ClientMessageReader {
    private let reader = RtmpChunkReader()
    private var buffer = Data()
    private var raw = Data()
    private var messages: [(RtmpMessage, Data)] = []

    func next(server: RtmpServerMock) async -> (RtmpMessage, Data) {
        while messages.isEmpty {
            let data = await server.receive(count: 1)
            raw += data
            buffer += data
            buffer = reader.read(data: buffer) { message in
                messages.append((message, raw))
                raw = Data()
            }
        }
        let (message, raw) = messages.removeFirst()
        if let message = message as? RtmpSetChunkSizeMessage {
            reader.maximumChunkSize = Int(message.size)
        }
        return (message, raw)
    }

    func nextMessage(server: RtmpServerMock) async -> RtmpMessage {
        await next(server: server).0
    }

    func nextCommand(server: RtmpServerMock) async throws -> RtmpCommandMessage {
        try #require(await nextMessage(server: server) as? RtmpCommandMessage)
    }
}

private struct PublishingStream {
    let modelMock: RtmpModelMock
    let processor: Processor
    let server: RtmpServerMock
    let rtmpStream: RtmpStream
    let reader: ClientMessageReader
}

private func makeStatus(code: String, description: String = "") -> AsValue {
    .object([
        "level": .string("status"),
        "code": .string(code),
        "description": .string(description),
    ])
}

private func sendCommand(server: RtmpServerMock,
                         transactionId: Int,
                         commandName: RtmpCommandName,
                         arguments: [AsValue],
                         maximumSize: Int = 128) async
{
    await server.send(chunk: RtmpChunk(
        type: .zero,
        chunkStreamId: 3,
        message: RtmpCommandMessage(
            streamId: 0,
            transactionId: transactionId,
            commandType: .amf0Command,
            commandName: commandName,
            commandObject: nil,
            arguments: arguments
        )
    ), maximumSize: maximumSize)
}

private func connectAndPublish() async throws -> PublishingStream {
    let modelMock = RtmpModelMock()
    let processor = Processor(delegate: modelMock, colorRange: .full)
    let server = try RtmpServerMock()
    let rtmpStream = RtmpStream(name: "test", processor: processor, delegate: modelMock, queue: rtmpQueue)
    let reader = ClientMessageReader()
    await rtmpStream.setUrl("rtmp://127.0.0.1:\(server.getLocalPort())/live/5")
    rtmpStream.connect()
    _ = await receiveC0C1(server: server)
    await sendS0S1(server: server)
    _ = await receiveC2(server: server)
    await sendS2(server: server)
    #expect(try await reader.nextCommand(server: server).commandName == .connect)
    await sendWindowAcknowledgementSize(server: server, chunkStreamId: 2, size: 2_500_000)
    #expect(await reader.nextMessage(server: server) is RtmpWindowAcknowledgementSizeMessage)
    await sendCommand(server: server,
                      transactionId: 1,
                      commandName: .result,
                      arguments: [makeStatus(code: "NetConnection.Connect.Success")])
    #expect(await reader.nextMessage(server: server) is RtmpSetChunkSizeMessage)
    #expect(await modelMock.waitForStatus() == "NetConnection.Connect.Success")
    #expect(try await reader.nextCommand(server: server).commandName == .releaseStream)
    #expect(try await reader.nextCommand(server: server).commandName == .fcPublish)
    let createStream = try await reader.nextCommand(server: server)
    #expect(createStream.commandName == .createStream)
    await sendCommand(server: server,
                      transactionId: createStream.transactionId,
                      commandName: .result,
                      arguments: [.number(1)])
    let publish = try await reader.nextCommand(server: server)
    #expect(publish.commandName == .publish)
    #expect(publish.streamId == 1)
    await sendCommand(server: server,
                      transactionId: 0,
                      commandName: .onStatus,
                      arguments: [makeStatus(code: "NetStream.Publish.Start")])
    #expect(await modelMock.waitForStatus() == "NetStream.Publish.Start")
    await modelMock.waitForConnected()
    let setDataFrame = try #require(await reader.nextMessage(server: server) as? RtmpDataMessage)
    #expect(setDataFrame.handlerName == "@setDataFrame")
    #expect(setDataFrame.streamId == 1)
    return PublishingStream(modelMock: modelMock,
                            processor: processor,
                            server: server,
                            rtmpStream: rtmpStream,
                            reader: reader)
}

private func expectUnpublish(_ stream: PublishingStream) async throws {
    #expect(try await stream.reader.nextCommand(server: stream.server).commandName == .fcUnpublish)
    let deleteStream = try await stream.reader.nextCommand(server: stream.server)
    #expect(deleteStream.commandName == .deleteStream)
    #expect(deleteStream.arguments == [.number(1)])
    let closeStream = try await stream.reader.nextCommand(server: stream.server)
    #expect(closeStream.commandName == .closeStream)
    #expect(closeStream.arguments == [.number(1)])
}

extension RtmpStreamSuite {
    @Test
    func pingIsAnsweredWithPong() async throws {
        let stream = try await connectAndPublish()
        await stream.server.send(chunk: RtmpChunk(
            type: .zero,
            chunkStreamId: 2,
            message: RtmpUserControlMessage(event: .ping, value: 1234)
        ))
        let (message, raw) = await stream.reader.next(server: stream.server)
        let pong = try #require(message as? RtmpUserControlMessage)
        #expect(pong.event == .pong)
        #expect(pong.value == 1234)
        #expect(raw.first == 0x02)
    }

    @Test
    func serverChunkSizeIsUsedWhenReading() async throws {
        let stream = try await connectAndPublish()
        await stream.server.send(chunk: RtmpChunk(
            type: .zero,
            chunkStreamId: 2,
            message: RtmpSetChunkSizeMessage(4096)
        ))
        await sendCommand(server: stream.server,
                          transactionId: 0,
                          commandName: .onStatus,
                          arguments: [makeStatus(code: "NetStream.Foo",
                                                 description: String(repeating: "x", count: 300))],
                          maximumSize: 4096)
        #expect(await stream.modelMock.waitForStatus() == "NetStream.Foo")
    }

    @Test
    func closeCommandUnpublishes() async throws {
        let stream = try await connectAndPublish()
        await sendCommand(server: stream.server, transactionId: 0, commandName: .close, arguments: [])
        try await expectUnpublish(stream)
    }

    @Test
    func connectClosedStatusUnpublishes() async throws {
        let stream = try await connectAndPublish()
        await sendCommand(server: stream.server,
                          transactionId: 0,
                          commandName: .onStatus,
                          arguments: [makeStatus(code: "NetConnection.Connect.Closed")])
        #expect(await stream.modelMock.waitForStatus() == "NetConnection.Connect.Closed")
        try await expectUnpublish(stream)
    }

    @Test
    func aacAudio() async throws {
        let stream = try await connectAndPublish()
        let format = makeAacFormat()
        stream.rtmpStream.audioEncoderOutputFormat(format)
        var (message, raw) = await stream.reader.next(server: stream.server)
        #expect(message.type == .audio)
        #expect(message.streamId == 1)
        #expect(message.timestamp == 0)
        #expect(message.encoded == Data([0xAF, 0x00, 0x11, 0x90]))
        #expect(raw.prefix(1) == Data([0x08]))
        var timestamps: [UInt32] = []
        for (index, pts) in [10240, 10261, 10282, 10303, 10324, 10345].enumerated() {
            stream.rtmpStream.audioEncoderOutputBuffer(
                makeAudioBuffer(format: format, payload: Data([UInt8(index), 1, 2])),
                mediaTime(Int64(pts))
            )
            (message, raw) = await stream.reader.next(server: stream.server)
            #expect(message.type == .audio)
            #expect(message.encoded == Data([0xAF, 0x01, UInt8(index), 1, 2]))
            #expect(raw.prefix(1) == Data([0x48]))
            timestamps.append(message.timestamp)
        }
        #expect(timestamps == [0, 20, 41, 61, 82, 102])
    }

    @Test
    func audioBuffersBeforeBaseOrOutOfOrderAreDropped() async throws {
        let stream = try await connectAndPublish()
        let format = makeAacFormat()
        var timestamps: [UInt32] = []
        for (index, pts) in [10240, 10200, 10261, 10250, 10282].enumerated() {
            stream.rtmpStream.audioEncoderOutputBuffer(
                makeAudioBuffer(format: format, payload: Data([UInt8(index)])),
                mediaTime(Int64(pts))
            )
        }
        for _ in 0 ..< 3 {
            let message = await stream.reader.nextMessage(server: stream.server)
            #expect(message.type == .audio)
            timestamps.append(message.timestamp)
        }
        #expect(timestamps == [0, 20, 41])
    }

    @Test
    func h264Video() async throws {
        let stream = try await connectAndPublish()
        let formatDescription = try makeH264FormatDescription()
        let avcC = try #require(MpegTsVideoConfigAvc.getAvcC(formatDescription))
        let encoder = stream.processor.getVideoEncoder()
        stream.rtmpStream.videoEncoderOutputFormat(encoder, formatDescription)
        var (message, raw) = await stream.reader.next(server: stream.server)
        #expect(message.type == .video)
        #expect(message.streamId == 1)
        #expect(message.timestamp == 0)
        #expect(message.encoded == Data([0x17, 0x00, 0x00, 0x00, 0x00]) + avcC)
        #expect(raw.prefix(1) == Data([0x09]))
        var timestamps: [UInt32] = []
        for (index, dts) in [10240, 10272, 10304, 10336, 10368].enumerated() {
            let isSync = index == 0
            try stream.rtmpStream.videoEncoderOutputSampleBuffer(
                encoder,
                makeVideoSampleBuffer(formatDescription: formatDescription,
                                      decodeTimeStamp: mediaTime(Int64(dts)),
                                      presentationTimeStamp: mediaTime(Int64(dts + 64)),
                                      isSync: isSync,
                                      payload: Data([0, 0, 0, 2, isSync ? 0x65 : 0x41, UInt8(index)])),
                .zero
            )
            (message, raw) = await stream.reader.next(server: stream.server)
            #expect(message.type == .video)
            #expect(message.encoded == Data([isSync ? 0x17 : 0x27, 0x01, 0x00, 0x00, 62,
                                             0, 0, 0, 2, isSync ? 0x65 : 0x41, UInt8(index)]))
            #expect(raw.prefix(1) == Data([0x49]))
            timestamps.append(message.timestamp)
        }
        #expect(timestamps == [0, 31, 62, 93, 125])
    }

    @Test
    func audioAndVideoShareBaseTimestamp() async throws {
        let stream = try await connectAndPublish()
        let formatDescription = try makeH264FormatDescription()
        try stream.rtmpStream.videoEncoderOutputSampleBuffer(
            stream.processor.getVideoEncoder(),
            makeVideoSampleBuffer(formatDescription: formatDescription,
                                  decodeTimeStamp: mediaTime(10240),
                                  presentationTimeStamp: mediaTime(10240),
                                  isSync: true,
                                  payload: Data([0, 0, 0, 1, 0x65])),
            .zero
        )
        #expect(await stream.reader.nextMessage(server: stream.server).type == .video)
        let format = makeAacFormat()
        stream.rtmpStream.audioEncoderOutputBuffer(
            makeAudioBuffer(format: format, payload: Data([1])),
            mediaTime(10200)
        )
        stream.rtmpStream.audioEncoderOutputBuffer(
            makeAudioBuffer(format: format, payload: Data([2])),
            mediaTime(10261)
        )
        stream.rtmpStream.audioEncoderOutputBuffer(
            makeAudioBuffer(format: format, payload: Data([3])),
            mediaTime(10282)
        )
        let first = await stream.reader.nextMessage(server: stream.server)
        #expect(first.type == .audio)
        #expect(first.timestamp == 0)
        #expect(first.encoded.last == 2)
        let second = await stream.reader.nextMessage(server: stream.server)
        #expect(second.timestamp == 20)
        #expect(second.encoded.last == 3)
    }
}
