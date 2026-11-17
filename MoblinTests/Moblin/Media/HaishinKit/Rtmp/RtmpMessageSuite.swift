import Foundation
@testable import Moblin
import Testing

struct RtmpMessageSuite {
    @Test
    func setChunkSizeEncode() {
        #expect(RtmpSetChunkSizeMessage(4096).encoded == Data([0x00, 0x00, 0x10, 0x00]))
    }

    @Test
    func setChunkSizeDecode() throws {
        let message = try #require(transfer(RtmpSetChunkSizeMessage(8192)) as? RtmpSetChunkSizeMessage)
        #expect(message.size == 8192)
    }

    @Test
    func windowAcknowledgementSizeEncode() {
        #expect(RtmpWindowAcknowledgementSizeMessage(2_500_000).encoded == Data([0x00, 0x26, 0x25, 0xA0]))
    }

    @Test
    func windowAcknowledgementSizeDecode() throws {
        let message = try #require(
            transfer(RtmpWindowAcknowledgementSizeMessage(100_000)) as? RtmpWindowAcknowledgementSizeMessage
        )
        #expect(message.size == 100_000)
    }

    @Test
    func acknowledgementEncode() {
        let message = RtmpAcknowledgementMessage()
        message.sequence = 0x0102_0304
        #expect(message.encoded == Data([0x01, 0x02, 0x03, 0x04]))
    }

    @Test
    func acknowledgementDecode() throws {
        let sent = RtmpAcknowledgementMessage()
        sent.sequence = 0xFFFF_FFFE
        let message = try #require(transfer(sent) as? RtmpAcknowledgementMessage)
        #expect(message.sequence == 0xFFFF_FFFE)
    }

    @Test
    func abortEncode() {
        let message = RtmpAbortMessge()
        message.chunkStreamId = 5
        #expect(message.encoded == Data([0x00, 0x00, 0x00, 0x05]))
    }

    @Test
    func abortDecode() throws {
        let sent = RtmpAbortMessge()
        sent.chunkStreamId = 9
        let message = try #require(transfer(sent) as? RtmpAbortMessge)
        #expect(message.chunkStreamId == 9)
    }

    @Test
    func setPeerBandwidthEncode() {
        #expect(RtmpSetPeerBandwidthMessage(size: 1000, limit: .dynamic).encoded
            == Data([0x00, 0x00, 0x03, 0xE8, 0x02]))
    }

    @Test
    func setPeerBandwidthDecode() throws {
        let message = try #require(
            transfer(RtmpSetPeerBandwidthMessage(
                size: 59_768_832,
                limit: .soft
            )) as? RtmpSetPeerBandwidthMessage
        )
        #expect(message.size == 59_768_832)
        #expect(message.limit == .soft)
    }

    @Test
    func setPeerBandwidthDecodeUnknownLimit() throws {
        let message = try #require(
            transfer(
                type: .bandwidth,
                payload: Data([0x00, 0x00, 0x03, 0xE8, 0x09])
            ) as? RtmpSetPeerBandwidthMessage
        )
        #expect(message.size == 1000)
        #expect(message.limit == .unknown)
    }

    @Test
    func userControlEncode() {
        #expect(RtmpUserControlMessage(event: .pong, value: 1234).encoded
            == Data([0x00, 0x07, 0x00, 0x00, 0x04, 0xD2]))
    }

    @Test
    func userControlDecode() throws {
        let message = try #require(
            transfer(RtmpUserControlMessage(event: .ping, value: -2)) as? RtmpUserControlMessage
        )
        #expect(message.event == .ping)
        #expect(message.value == -2)
    }

    @Test
    func userControlDecodeUnknownEvent() throws {
        let message = try #require(
            transfer(
                type: .user,
                payload: Data([0x00, 0x42, 0x00, 0x00, 0x00, 0x01])
            ) as? RtmpUserControlMessage
        )
        #expect(message.event == .unknown)
        #expect(message.value == 1)
    }

    @Test
    func audioDecode() throws {
        let message = try #require(transfer(RtmpAudioMessage(
            streamId: 1,
            timestamp: 2,
            payload: Data([3, 4])
        )))
        #expect(message is RtmpAudioMessage)
        #expect(message.streamId == 1)
        #expect(message.timestamp == 2)
        #expect(message.encoded == Data([3, 4]))
    }

    @Test
    func videoDecode() throws {
        let message = try #require(transfer(RtmpVideoMessage(
            streamId: 1,
            timestamp: 2,
            payload: Data([3, 4])
        )))
        #expect(message is RtmpVideoMessage)
        #expect(message.encoded == Data([3, 4]))
    }

    @Test
    func aggregateDecode() throws {
        let message = try #require(transfer(type: .aggregate, payload: Data([1, 2, 3])))
        #expect(message is RtmpAggregateMessage)
        #expect(message.encoded == Data([1, 2, 3]))
    }

    @Test
    func commandEncode() {
        let message = RtmpCommandMessage(streamId: 0,
                                         transactionId: 2,
                                         commandType: .amf0Command,
                                         commandName: .createStream,
                                         commandObject: nil,
                                         arguments: [])
        let encoder = Amf0Encoder()
        encoder.encode(.string("createStream"))
        encoder.encode(.number(2))
        encoder.encode(.null)
        #expect(message.encoded == encoder.data)
    }

    @Test
    func commandDecode() throws {
        let message = try #require(transfer(RtmpCommandMessage(
            streamId: 1,
            transactionId: 4,
            commandType: .amf0Command,
            commandName: .onStatus,
            commandObject: ["a": .number(1)],
            arguments: [.string("x"), .null, .object(["code": .string("NetStream.Publish.Start")])]
        )) as? RtmpCommandMessage)
        #expect(message.type == .amf0Command)
        #expect(message.streamId == 1)
        #expect(message.commandName == .onStatus)
        #expect(message.transactionId == 4)
        #expect(message.commandObject == ["a": .number(1)])
        #expect(message.arguments == [
            .string("x"),
            .null,
            .object(["code": .string("NetStream.Publish.Start")]),
        ])
    }

    @Test
    func amf3CommandEncodeStartsWithZero() {
        let message = RtmpCommandMessage(streamId: 0,
                                         transactionId: 1,
                                         commandType: .amf3Command,
                                         commandName: .connect,
                                         commandObject: nil,
                                         arguments: [])
        #expect(message.encoded.first == 0)
    }

    @Test
    func amf3CommandDecode() throws {
        let message = try #require(transfer(RtmpCommandMessage(
            streamId: 0,
            transactionId: 3,
            commandType: .amf3Command,
            commandName: .result,
            commandObject: nil,
            arguments: [.number(5)]
        )) as? RtmpCommandMessage)
        #expect(message.type == .amf3Command)
        #expect(message.commandName == .result)
        #expect(message.transactionId == 3)
        #expect(message.commandObject == [:])
        #expect(message.arguments == [.number(5)])
    }

    @Test
    func commandDecodeUnknownName() throws {
        let encoder = Amf0Encoder()
        encoder.encode(.string("foo"))
        encoder.encode(.number(7))
        encoder.encode(.null)
        let message = try #require(transfer(type: .amf0Command, payload: encoder.data) as? RtmpCommandMessage)
        #expect(message.commandName == .unknown)
        #expect(message.transactionId == 7)
    }

    @Test
    func commandDecodeMalformed() throws {
        let message = try #require(transfer(
            type: .amf0Command,
            payload: Data([0x02, 0x00])
        ) as? RtmpCommandMessage)
        #expect(message.commandName == .unknown)
        #expect(message.commandObject == nil)
        #expect(message.arguments.isEmpty)
    }

    @Test
    func dataEncode() {
        let message = RtmpDataMessage(streamId: 1,
                                      dataType: .amf0Data,
                                      timestamp: 0,
                                      handlerName: "@setDataFrame",
                                      arguments: [.string("onMetaData")])
        let encoder = Amf0Encoder()
        encoder.encode(.string("@setDataFrame"))
        encoder.encode(.string("onMetaData"))
        #expect(message.encoded == encoder.data)
    }

    @Test
    func dataDecode() throws {
        let message = try #require(transfer(RtmpDataMessage(
            streamId: 1,
            dataType: .amf0Data,
            timestamp: 9,
            handlerName: "@setDataFrame",
            arguments: [.string("onMetaData"), .object(["width": .number(1280)])]
        )) as? RtmpDataMessage)
        #expect(message.type == .amf0Data)
        #expect(message.timestamp == 9)
        #expect(message.handlerName == "@setDataFrame")
        #expect(message.arguments == [.string("onMetaData"), .object(["width": .number(1280)])])
    }

    @Test
    func amf3DataDecode() throws {
        let message = try #require(transfer(RtmpDataMessage(
            streamId: 1,
            dataType: .amf3Data,
            timestamp: 0,
            handlerName: "onFoo",
            arguments: [.bool(true)]
        )) as? RtmpDataMessage)
        #expect(message.type == .amf3Data)
        #expect(message.handlerName == "onFoo")
        #expect(message.arguments == [.bool(true)])
    }
}

private func transfer(_ message: RtmpMessage) -> RtmpMessage? {
    read(data: Data(RtmpChunk(type: .zero, chunkStreamId: 3, message: message).split(maximumSize: 128)
            .joined()))
}

private func transfer(type: RtmpMessageType, payload: Data) -> RtmpMessage? {
    let message = RtmpMessage(type: type)
    message.encoded = payload
    return transfer(message)
}

private func read(data: Data) -> RtmpMessage? {
    var messages: [RtmpMessage] = []
    let remaining = RtmpChunkReader().read(data: data) { messages.append($0) }
    #expect(remaining.isEmpty)
    #expect(messages.count == 1)
    return messages.first
}
