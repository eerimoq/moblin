import AVFoundation
@testable import Moblin
import Testing

private let rtmpQueue = DispatchQueue(label: "test")

private class ModelMock {
    private let status = MessageQueue<String>()
    private let connected = MessageQueue<Void>()

    func waitForStatus() async -> String {
        return await status.get()
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
        return await localPort.get()
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
                self.handleData(data: content)
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
        let processor = Processor()
        let modelMock = ModelMock()
        let server = try RtmpServerMock()
        let rtmpStream = RtmpStream(name: "test",
                                    processor: processor,
                                    delegate: modelMock,
                                    queue: rtmpQueue)
        rtmpStream.setUrl("rtmp://127.0.0.1:\(await server.getLocalPort())/live/\(streamKey)")
        rtmpStream.connect()
        let c0c1 = await receiveC0C1(server: server)
        #expect(c0c1[0] == RtmpHandshake.protocolVersion)
        await sendS0S1(server: server)
        _ = await receiveC2(server: server)
        await sendS2(server: server)
        let reader = ByteReader(data: await server.receive(count: 273))
        try expectBasicHeader(reader: reader, fmt: 0, csId: 3)
        try expectMessageHeader(reader: reader, size: 259, messageTypeId: 20, messageStreamId: 0)
        try expectConnectCommandMessage(reader: reader)
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
                arguments: [.object([
                    "level": .string("status"),
                    "code": .string("NetConnection.Connect.Success"),
                    "description": .string("Connection succeeded."),
                ])]
            )
        ))
        let setChunkSize = await receiveSetChunkSize(server: server)
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
                arguments: [.object([
                    "level": .string("status"),
                    "code": .string("NetStream.Publish.Start"),
                    "description": .string("Start publishing."),
                ])]
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
        let processor = Processor()
        let modelMock = ModelMock()
        let server = try RtmpServerMock()
        let rtmpStream = RtmpStream(name: "test",
                                    processor: processor,
                                    delegate: modelMock,
                                    queue: rtmpQueue)
        rtmpStream.setUrl("rtmp://127.0.0.1:\(await server.getLocalPort())/live/\(streamKey)")
        rtmpStream.connect()
        let c0c1 = await receiveC0C1(server: server)
        #expect(c0c1[0] == RtmpHandshake.protocolVersion)
        await sendS0S1(server: server)
        _ = await receiveC2(server: server)
        await sendS2(server: server)
        let reader = ByteReader(data: await server.receive(count: 273))
        try expectBasicHeader(reader: reader, fmt: 0, csId: 3)
        try expectMessageHeader(reader: reader, size: 259, messageTypeId: 20, messageStreamId: 0)
        try expectConnectCommandMessage(reader: reader)
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
                arguments: [.object([
                    "level": .string("status"),
                    "code": .string("NetConnection.Connect.Success"),
                    "description": .string("Connection succeeded."),
                    "objectEncoding": .number(0),
                ])]
            )
        ))
        // Nothing below is updated to match Wireshark.
        let setChunkSize = await receiveSetChunkSize(server: server)
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
                arguments: [.object([
                    "level": .string("status"),
                    "code": .string("NetStream.Publish.Start"),
                    "description": .string("Start publishing."),
                ])]
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
}

private func receiveC0C1(server: RtmpServerMock) async -> Data {
    return await server.receive(count: RtmpHandshake.sigSize + 1)
}

private func sendS0S1(server: RtmpServerMock) async {
    await server.send(data: Data(count: RtmpHandshake.sigSize + 1))
}

private func receiveC2(server: RtmpServerMock) async -> Data {
    return await server.receive(count: RtmpHandshake.sigSize)
}

private func sendS2(server: RtmpServerMock) async {
    await server.send(data: Data(count: RtmpHandshake.sigSize))
}

private func sendWindowAcknowledgementSize(server: RtmpServerMock, chunkStreamId: UInt16, size: UInt32) async {
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

private func sendBasicHeader(server: RtmpServerMock, fmt: UInt8, csId: UInt8) async {
    await server.send(data: Data([fmt << 6 | csId]))
}

private func sendMessageHeader(server: RtmpServerMock,
                               size: UInt32,
                               messageTypeId: UInt8,
                               messageStreamId: UInt32) async
{
    let writer = ByteWriter()
    writer.writeBytes(Data([0, 0, 0]))
    writer.writeUInt24(size)
    writer.writeUInt8(messageTypeId)
    writer.writeUInt32(messageStreamId)
    await server.send(data: writer.data)
}

private func expectBasicHeader(reader: ByteReader, fmt: UInt8, csId: UInt8) throws {
    #expect(try reader.readUInt8() == fmt << 6 | csId)
}

private func expectMessageHeader(reader: ByteReader,
                                 size: UInt32,
                                 messageTypeId: UInt8,
                                 messageStreamId: UInt32) throws
{
    try reader.skipBytes(3)
    #expect(try reader.readUInt24() == size)
    #expect(try reader.readUInt8() == messageTypeId)
    #expect(try reader.readUInt32() == messageStreamId)
}

private func expectConnectCommandMessage(reader: ByteReader) throws {
    var chunk = try reader.readBytes(128)
    #expect(try reader.readUInt8() == 0xC3)
    chunk += try reader.readBytes(128)
    #expect(try reader.readUInt8() == 0xC3)
    chunk += try reader.readBytes(3)
    #expect(reader.bytesAvailable == 0)
    let reader = ByteReader(data: chunk)
    #expect(try reader.readUInt8() == Amf0Type.string.rawValue)
    #expect(try reader.readUInt16() == 7)
    #expect(try reader.readUtf8Bytes(7) == "connect")
    #expect(try reader.readUInt8() == Amf0Type.number.rawValue)
    #expect(try reader.readDouble() == 1)
    let deserializer = try Amf0Decoder(data: reader.readBytes(reader.bytesAvailable))
    let connectMessage = try deserializer.decode()
    guard case let .object(connectMessage) = connectMessage else {
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
    #expect(reader.bytesAvailable == 0)
}

private func expectWindowAcknowledgementSize(server: RtmpServerMock) async throws {
    let data = await server.receive(count: 16)
    let chunk = RtmpChunk(data: data, size: data.count)!
    #expect(chunk.type == .zero)
    #expect(chunk.chunkStreamId == 2)
    let message = chunk.message as! RtmpWindowAcknowledgementSizeMessage
    #expect(message.size == 100_000)
}

private func receiveCommandMessage(server: RtmpServerMock, size: Int) async throws -> RtmpCommandMessage {
    let data = await server.receive(count: size)
    let chunk = RtmpChunk(data: data, size: data.count)!
    return chunk.message as! RtmpCommandMessage
}

private func receiveSetChunkSize(server: RtmpServerMock) async -> RtmpSetChunkSizeMessage {
    let data = await server.receive(count: 16)
    let chunk = RtmpChunk(data: data, size: data.count)!
    return chunk.message as! RtmpSetChunkSizeMessage
}
