import Foundation
@testable import Moblin
import Testing

struct RtmpChunkSuite {
    struct BasicHeaderCase: CustomTestStringConvertible {
        let type: RtmpChunkType
        let chunkStreamId: UInt16
        let expected: Data

        var testDescription: String {
            "type \(type.rawValue), chunk stream \(chunkStreamId)"
        }
    }

    @Test(arguments: [
        BasicHeaderCase(type: .zero, chunkStreamId: 2, expected: Data([0x02])),
        BasicHeaderCase(type: .one, chunkStreamId: 3, expected: Data([0x43])),
        BasicHeaderCase(type: .two, chunkStreamId: 4, expected: Data([0x84])),
        BasicHeaderCase(type: .three, chunkStreamId: 63, expected: Data([0xFF])),
        BasicHeaderCase(type: .zero, chunkStreamId: 64, expected: Data([0x00, 0x00])),
        BasicHeaderCase(type: .three, chunkStreamId: 319, expected: Data([0xC0, 0xFF])),
        BasicHeaderCase(type: .zero, chunkStreamId: 320, expected: Data([0x01, 0x00, 0x01])),
        BasicHeaderCase(type: .one, chunkStreamId: 400, expected: Data([0x41, 0x50, 0x01])),
    ])
    func basicHeader(_ testCase: BasicHeaderCase) {
        #expect(testCase.type.toBasicHeader(testCase.chunkStreamId) == testCase.expected)
    }

    @Test
    func encodeTypeZero() {
        let message = RtmpSetChunkSizeMessage(4096)
        message.streamId = 1
        message.timestamp = 0x010203
        let chunk = RtmpChunk(type: .zero, chunkStreamId: 3, message: message)
        #expect(chunk.encode() == Data([
            0x03, 0x01, 0x02, 0x03, 0x00, 0x00, 0x04, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10, 0x00,
        ]))
    }

    @Test
    func encodeTypeOne() {
        let chunk = RtmpChunk(type: .one,
                              chunkStreamId: 8,
                              message: RtmpAudioMessage(streamId: 1, timestamp: 20, payload: Data([1, 2, 3])))
        #expect(chunk.encode() == Data([0x48, 0x00, 0x00, 0x14, 0x00, 0x00, 0x03, 0x08, 1, 2, 3]))
    }

    @Test
    func encodeTypeZeroWithExtendedTimestamp() {
        let chunk = RtmpChunk(type: .zero,
                              chunkStreamId: 4,
                              message: RtmpAudioMessage(
                                  streamId: 1,
                                  timestamp: 0x0100_0000,
                                  payload: Data([7])
                              ))
        #expect(chunk.encode() == Data([
            0x04, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x01, 0x08, 0x01, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 7,
        ]))
    }

    @Test
    func encodeTypeZeroWithTimestampAtExtendedMarker() {
        let chunk = RtmpChunk(type: .zero,
                              chunkStreamId: 4,
                              message: RtmpAudioMessage(streamId: 1, timestamp: 0xFFFFFF, payload: Data([7])))
        #expect(chunk.encode() == Data([
            0x04, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x01, 0x08, 0x01, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 7,
        ]))
    }

    @Test
    func defaultChunkIsTypeZeroOnCommandChunkStream() {
        let chunk = RtmpChunk(message: RtmpSetChunkSizeMessage(128))
        #expect(chunk.encode().prefix(1) == Data([0x03]))
    }

    @Test
    func splitSmallerThanMaximumSize() {
        let chunk = RtmpChunk(type: .zero,
                              chunkStreamId: 8,
                              message: RtmpAudioMessage(streamId: 1, timestamp: 5, payload: makePayload(128)))
        let chunks = chunk.split(maximumSize: 128)
        let expected: [Data] = [chunk.encode()]
        #expect(chunks == expected)
    }

    @Test
    func splitOneByteLargerThanMaximumSize() {
        let payload = makePayload(129)
        let chunk = RtmpChunk(type: .zero,
                              chunkStreamId: 8,
                              message: RtmpAudioMessage(streamId: 1, timestamp: 5, payload: payload))
        let chunks = chunk.split(maximumSize: 128)
        let expected: [Data] = [chunk.encode().prefix(12 + 128), Data([0xC8]) + payload.suffix(1)]
        #expect(chunks == expected)
    }

    @Test
    func splitIntoThreeChunks() {
        let payload = makePayload(300)
        let chunk = RtmpChunk(type: .zero,
                              chunkStreamId: 8,
                              message: RtmpAudioMessage(streamId: 1, timestamp: 5, payload: payload))
        let chunks = chunk.split(maximumSize: 128)
        let expected: [Data] = [
            chunk.encode().prefix(12 + 128),
            Data([0xC8]) + payload[128 ..< 256],
            Data([0xC8]) + payload[256 ..< 300],
        ]
        #expect(chunks == expected)
    }

    @Test
    func splitSetsMessageLengthToEncodedChunkSize() {
        let message = RtmpAudioMessage(streamId: 1, timestamp: 5, payload: makePayload(300))
        _ = RtmpChunk(type: .zero, chunkStreamId: 8, message: message).split(maximumSize: 128)
        #expect(message.length == 12 + 300)
    }

    @Test
    func splitTypeOneSetsMessageLengthToEncodedChunkSize() {
        let message = RtmpAudioMessage(streamId: 1, timestamp: 5, payload: makePayload(10))
        _ = RtmpChunk(type: .one, chunkStreamId: 8, message: message).split(maximumSize: 128)
        #expect(message.length == 8 + 10)
    }

    @Test
    func splitWithExtendedTimestamp() {
        let payload = makePayload(200)
        let chunk = RtmpChunk(type: .zero,
                              chunkStreamId: 8,
                              message: RtmpAudioMessage(
                                  streamId: 1,
                                  timestamp: 0x0100_0000,
                                  payload: payload
                              ))
        let chunks = chunk.split(maximumSize: 128)
        let expected: [Data] = [
            chunk.encode().prefix(16 + 128),
            Data([0xC8, 0x01, 0x00, 0x00, 0x00]) + payload[128 ..< 200],
        ]
        #expect(chunks == expected)
    }

    @Test
    func splitWithTwoByteBasicHeader() {
        let payload = makePayload(200)
        let chunk = RtmpChunk(type: .zero,
                              chunkStreamId: 100,
                              message: RtmpAudioMessage(streamId: 1, timestamp: 5, payload: payload))
        let chunks = chunk.split(maximumSize: 128)
        let expected: [Data] = [
            chunk.encode().prefix(13 + 128),
            Data([0xC0, 36]) + payload[128 ..< 200],
        ]
        #expect(chunks == expected)
    }

    @Test
    func splitWithLargerMaximumSize() {
        let payload = makePayload(10000)
        let chunk = RtmpChunk(type: .zero,
                              chunkStreamId: 9,
                              message: RtmpVideoMessage(streamId: 1, timestamp: 5, payload: payload))
        let chunks = chunk.split(maximumSize: 8192)
        let expected: [Data] = [
            chunk.encode().prefix(12 + 8192),
            Data([0xC9]) + payload[8192 ..< 10000],
        ]
        #expect(chunks == expected)
    }

    @Test
    func splitChunksAreReadBack() throws {
        let payload = makePayload(1000)
        let chunk = RtmpChunk(type: .zero,
                              chunkStreamId: 9,
                              message: RtmpVideoMessage(streamId: 1, timestamp: 33, payload: payload))
        let reader = RtmpChunkReader()
        reader.maximumChunkSize = 300
        var messages: [RtmpMessage] = []
        let remaining = reader.read(data: Data(chunk.split(maximumSize: 300).joined())) {
            messages.append($0)
        }
        #expect(remaining.isEmpty)
        let message = try #require(messages.first)
        #expect(messages.count == 1)
        #expect(message.type == .video)
        #expect(message.timestamp == 33)
        #expect(message.encoded == payload)
    }

    @Test
    func readerClearRestoresDefaultChunkSize() {
        let reader = RtmpChunkReader()
        reader.maximumChunkSize = 4096
        reader.clear()
        #expect(reader.maximumChunkSize == RtmpChunk.defaultSize)
    }

    @Test
    func readerClearDropsPartialMessage() {
        let reader = RtmpChunkReader()
        let payload = makePayload(200)
        let data = Data(RtmpChunk(type: .zero,
                                  chunkStreamId: 8,
                                  message: RtmpAudioMessage(streamId: 1, timestamp: 5, payload: payload))
                .split(maximumSize: 128).joined())
        var messages: [RtmpMessage] = []
        #expect(reader.read(data: data.prefix(12 + 128)) { messages.append($0) }.isEmpty)
        reader.clear()
        let ack = RtmpAcknowledgementMessage()
        ack.sequence = 7
        let ackData = RtmpChunk(type: .zero, chunkStreamId: 2, message: ack).encode()
        #expect(reader.read(data: ackData) { messages.append($0) }.isEmpty)
        #expect(messages.compactMap { ($0 as? RtmpAcknowledgementMessage)?.sequence } == [7])
    }
}

private func makePayload(_ count: Int) -> Data {
    Data((0 ..< count).map { UInt8($0 % 251) })
}
