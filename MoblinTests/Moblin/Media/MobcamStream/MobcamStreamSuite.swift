import Foundation
@testable import Moblin
import Testing

private func packVideoFrame(_ presentationTimeStamp: UInt64, _ isSync: Bool, _ units: Data) -> Data {
    units.withUnsafeBytes {
        packMobcamStreamVideoFrame(presentationTimeStamp: presentationTimeStamp, isSync: isSync, units: $0)
    }
}

private func packAudioFrame(_ presentationTimeStamp: UInt64, _ unit: Data) -> Data {
    unit.withUnsafeBytes {
        packMobcamStreamAudioFrame(presentationTimeStamp: presentationTimeStamp, unit: $0)
    }
}

private func readAll(_ reader: MobcamStreamMessageReader) throws -> [(MobcamStreamMessageType, Data)] {
    var messages: [(MobcamStreamMessageType, Data)] = []
    while let message = try reader.read() {
        messages.append(message)
    }
    return messages
}

struct MobcamStreamSuite {
    @Test
    func hostHelloRoundTrip() throws {
        let reader = MobcamStreamMessageReader()
        reader.append(packMobcamStreamHostHello())
        let messages = try readAll(reader)
        #expect(messages.count == 1)
        #expect(messages[0].0 == .hostHello)
        try unpackMobcamStreamHostHello(messages[0].1)
    }

    @Test
    func hostHelloBadVersion() throws {
        var message = packMobcamStreamHostHello()
        message[message.count - 1] = mobcamStreamProtocolVersion + 1
        let reader = MobcamStreamMessageReader()
        reader.append(message)
        let messages = try readAll(reader)
        #expect(throws: MobcamStreamProtocolError.self) {
            try unpackMobcamStreamHostHello(messages[0].1)
        }
    }

    @Test
    func deviceHello() throws {
        let reader = MobcamStreamMessageReader()
        reader.append(packMobcamStreamDeviceHello(MobcamStreamDeviceInfo(name: "Erik", version: "1.2.3")))
        let messages = try readAll(reader)
        #expect(messages.count == 1)
        #expect(messages[0].0 == .deviceHello)
        let payload = ByteReader(data: messages[0].1)
        #expect(try payload.readUInt8() == mobcamStreamProtocolVersion)
        let length = try Int(payload.readUInt32())
        let info = try JSONDecoder().decode(MobcamStreamDeviceInfo.self, from: payload.readBytes(length))
        #expect(info.name == "Erik")
        #expect(info.version == "1.2.3")
    }

    @Test
    func videoConfigAndFrame() throws {
        let reader = MobcamStreamMessageReader()
        reader.append(packMobcamStreamVideoConfig(codec: .hevc,
                                                  width: 1920,
                                                  height: 1080,
                                                  configurationRecord: Data([1, 2, 3])))
        reader.append(packVideoFrame(0x0102_0304_0506_0708, true, Data([9, 8, 7])))
        let messages = try readAll(reader)
        #expect(messages.count == 2)
        #expect(messages[0].0 == .videoConfig)
        let config = ByteReader(data: messages[0].1)
        #expect(try config.readUInt8() == MobcamStreamVideoCodec.hevc.rawValue)
        #expect(try config.readUInt16() == 1920)
        #expect(try config.readUInt16() == 1080)
        #expect(try config.readUInt32() == 3)
        #expect(try config.readBytes(3) == Data([1, 2, 3]))
        #expect(messages[1].0 == .videoFrame)
        let frame = ByteReader(data: messages[1].1)
        #expect(try frame.readUInt64() == 0x0102_0304_0506_0708)
        #expect(try frame.readUInt8() == 1)
        #expect(try frame.readBytes(3) == Data([9, 8, 7]))
    }

    @Test
    func audioConfigAndFrame() throws {
        let reader = MobcamStreamMessageReader()
        reader.append(packMobcamStreamAudioConfig(codec: .aac,
                                                  sampleRate: 48000,
                                                  channels: 2,
                                                  configurationRecord: Data([0x11, 0x90])))
        reader.append(packAudioFrame(42, Data([1, 2])))
        let messages = try readAll(reader)
        #expect(messages.count == 2)
        let config = ByteReader(data: messages[0].1)
        #expect(try config.readUInt8() == MobcamStreamAudioCodec.aac.rawValue)
        #expect(try config.readUInt32() == 48000)
        #expect(try config.readUInt8() == 2)
        #expect(try config.readUInt32() == 2)
        #expect(try config.readBytes(2) == Data([0x11, 0x90]))
        let frame = ByteReader(data: messages[1].1)
        #expect(try frame.readUInt64() == 42)
        #expect(try frame.readBytes(2) == Data([1, 2]))
    }

    @Test
    func opusAudioConfig() throws {
        let reader = MobcamStreamMessageReader()
        reader.append(packMobcamStreamAudioConfig(
            codec: .opus,
            sampleRate: 48000,
            channels: 2,
            configurationRecord: packMobcamStreamOpusHead(sampleRate: 48000, channels: 2)
        ))
        let messages = try readAll(reader)
        #expect(messages.count == 1)
        let config = ByteReader(data: messages[0].1)
        #expect(try config.readUInt8() == MobcamStreamAudioCodec.opus.rawValue)
        #expect(try config.readUInt32() == 48000)
        #expect(try config.readUInt8() == 2)
        #expect(try config.readUInt32() == 19)
        #expect(try config.readBytes(19) == Data([
            0x4F, 0x70, 0x75, 0x73, 0x48, 0x65, 0x61, 0x64,
            1,
            2,
            0, 0,
            0x80, 0xBB, 0x00, 0x00,
            0, 0,
            0,
        ]))
    }

    @Test
    func splitOverManyReceives() throws {
        let message = packVideoFrame(1, false, Data([1, 2, 3]))
        let reader = MobcamStreamMessageReader()
        for byte in message.dropLast() {
            reader.append(Data([byte]))
            #expect(try reader.read() == nil)
        }
        reader.append(Data([message[message.count - 1]]))
        let messages = try readAll(reader)
        #expect(messages.count == 1)
        #expect(messages[0].0 == .videoFrame)
    }

    @Test
    func manyMessagesInOneReceive() throws {
        var data = Data()
        for index in 0 ..< 10 {
            data += packAudioFrame(UInt64(index), Data([UInt8(index)]))
        }
        let reader = MobcamStreamMessageReader()
        reader.append(data)
        let messages = try readAll(reader)
        #expect(messages.count == 10)
        for (index, message) in messages.enumerated() {
            let frame = ByteReader(data: message.1)
            #expect(try frame.readUInt64() == UInt64(index))
            #expect(try frame.readUInt8() == UInt8(index))
        }
    }

    @Test
    func unknownMessageType() {
        let reader = MobcamStreamMessageReader()
        var data = Data(count: 5)
        data[0] = 0x7F
        reader.append(data)
        #expect(throws: MobcamStreamProtocolError.self) {
            _ = try reader.read()
        }
    }
}
