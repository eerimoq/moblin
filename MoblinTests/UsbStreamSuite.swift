import Foundation
@testable import Moblin
import Testing

private func readAll(_ reader: UsbStreamMessageReader) throws -> [(UsbStreamMessageType, Data)] {
    var messages: [(UsbStreamMessageType, Data)] = []
    while let message = try reader.read() {
        messages.append(message)
    }
    return messages
}

struct UsbStreamSuite {
    @Test
    func hostHelloRoundTrip() throws {
        let reader = UsbStreamMessageReader()
        reader.append(packUsbStreamHostHello())
        let messages = try readAll(reader)
        #expect(messages.count == 1)
        #expect(messages[0].0 == .hostHello)
        try unpackUsbStreamHostHello(messages[0].1)
    }

    @Test
    func hostHelloBadMagic() throws {
        var message = packUsbStreamHostHello()
        message[5] = 0x58
        let reader = UsbStreamMessageReader()
        reader.append(message)
        let messages = try readAll(reader)
        #expect(throws: UsbStreamProtocolError.self) {
            try unpackUsbStreamHostHello(messages[0].1)
        }
    }

    @Test
    func hostHelloBadVersion() throws {
        var message = packUsbStreamHostHello()
        message[message.count - 1] = usbStreamProtocolVersion + 1
        let reader = UsbStreamMessageReader()
        reader.append(message)
        let messages = try readAll(reader)
        #expect(throws: UsbStreamProtocolError.self) {
            try unpackUsbStreamHostHello(messages[0].1)
        }
    }

    @Test
    func deviceHello() throws {
        let reader = UsbStreamMessageReader()
        reader.append(packUsbStreamDeviceHello(UsbStreamDeviceInfo(name: "Erik", version: "1.2.3")))
        let messages = try readAll(reader)
        #expect(messages.count == 1)
        #expect(messages[0].0 == .deviceHello)
        let payload = ByteReader(data: messages[0].1)
        #expect(try payload.readUInt8() == usbStreamProtocolVersion)
        let length = try Int(payload.readUInt32())
        let info = try JSONDecoder().decode(UsbStreamDeviceInfo.self, from: payload.readBytes(length))
        #expect(info.name == "Erik")
        #expect(info.version == "1.2.3")
    }

    @Test
    func videoConfigAndFrame() throws {
        let reader = UsbStreamMessageReader()
        reader.append(packUsbStreamVideoConfig(codec: .hevc,
                                               width: 1920,
                                               height: 1080,
                                               configurationRecord: Data([1, 2, 3])))
        reader.append(packUsbStreamVideoFrame(presentationTimeStamp: 0x0102_0304_0506_0708,
                                              isSync: true,
                                              units: Data([9, 8, 7])))
        let messages = try readAll(reader)
        #expect(messages.count == 2)
        #expect(messages[0].0 == .videoConfig)
        let config = ByteReader(data: messages[0].1)
        #expect(try config.readUInt8() == UsbStreamVideoCodec.hevc.rawValue)
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
        let reader = UsbStreamMessageReader()
        reader.append(packUsbStreamAudioConfig(codec: .aac,
                                               sampleRate: 48000,
                                               channels: 2,
                                               configurationRecord: Data([0x11, 0x90])))
        reader.append(packUsbStreamAudioFrame(presentationTimeStamp: 42, unit: Data([1, 2])))
        let messages = try readAll(reader)
        #expect(messages.count == 2)
        let config = ByteReader(data: messages[0].1)
        #expect(try config.readUInt8() == UsbStreamAudioCodec.aac.rawValue)
        #expect(try config.readUInt32() == 48000)
        #expect(try config.readUInt8() == 2)
        #expect(try config.readUInt32() == 2)
        #expect(try config.readBytes(2) == Data([0x11, 0x90]))
        let frame = ByteReader(data: messages[1].1)
        #expect(try frame.readUInt64() == 42)
        #expect(try frame.readBytes(2) == Data([1, 2]))
    }

    @Test
    func splitOverManyReceives() throws {
        let message = packUsbStreamVideoFrame(presentationTimeStamp: 1, isSync: false, units: Data([1, 2, 3]))
        let reader = UsbStreamMessageReader()
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
            data += packUsbStreamAudioFrame(presentationTimeStamp: UInt64(index), unit: Data([UInt8(index)]))
        }
        let reader = UsbStreamMessageReader()
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
        let reader = UsbStreamMessageReader()
        var data = Data(count: 5)
        data.setUInt32Be(value: 1)
        data[4] = 0x7F
        reader.append(data)
        #expect(throws: UsbStreamProtocolError.self) {
            _ = try reader.read()
        }
    }

    @Test
    func tooLongMessage() {
        let reader = UsbStreamMessageReader()
        var data = Data(count: 5)
        data.setUInt32Be(value: 0xFFFF_FFFF)
        reader.append(data)
        #expect(throws: UsbStreamProtocolError.self) {
            _ = try reader.read()
        }
    }

    @Test
    func zeroLengthMessage() {
        let reader = UsbStreamMessageReader()
        reader.append(Data(count: 4))
        #expect(throws: UsbStreamProtocolError.self) {
            _ = try reader.read()
        }
    }
}
