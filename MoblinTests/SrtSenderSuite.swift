import Foundation
@testable import Moblin
import Testing

private class ModelMock {
    private let connected = MessageQueue<Void>()
    private let disconnected = MessageQueue<Void>()
    private let packets = MessageQueue<String>()

    func waitForConnected() async {
        await connected.get()
    }

    func waitForDisconnected() async {
        await disconnected.get()
    }

    func waitForPacket() async -> String {
        return await packets.get()
    }
}

extension ModelMock: SrtSenderDelegate {
    func srtSenderConnected() {
        connected.put(())
    }

    func srtSenderDisconnected() {
        disconnected.put(())
    }

    func srtSenderOutput(packet: Data) {
        packets.put(packet.hexString())
    }
}

struct SrtSenderSuite {
    @Test
    func connectDisconnect() async throws {
        let sender = SrtSender(streamId: "1234", latency: 2000)
        let model = ModelMock()
        sender.delegate = model
        sender.start()
        _ = checkInductionHandshake(packet: await model.waitForPacket())
        try sender.input(packet: createInductionHandshake())
        _ = checkConclusionHandshake(packet: await model.waitForPacket())
        try sender.input(packet: createConclusionHandshake())
        await model.waitForConnected()
        sender.send(now: .now.advanced(by: .seconds(6)))
        await model.waitForDisconnected()
    }

    private func checkInductionHandshake(packet: String) -> (UInt32, UInt32) {
        #expect(packet.count == 128)
        #expect(packet.substring(begin: 0, end: 16) == "8000000000000000")
        let timestamp = UInt32(packet.substring(begin: 16, end: 24), radix: 16)!
        #expect(packet.substring(begin: 24, end: 48) == "000000000000000400000002")
        let sequenceNumber = UInt32(packet.substring(begin: 48, end: 56), radix: 16)!
        #expect(packet
            .substring(begin: 56, end: 128) ==
            "000005dc00002000000000012ab1f77c000000000100007f000000000000000000000000")
        return (timestamp, sequenceNumber)
    }

    private func createInductionHandshake() throws -> Data {
        return try Data(hexString: """
        80000000000000000000000000000000000000040000000200000fe6000005dc\
        00002000000000012ab1f77c000000000100007f000000000000000000000000
        """)
    }

    private func checkConclusionHandshake(packet: String) -> (UInt32, UInt32) {
        #expect(packet.count == 176)
        #expect(packet.substring(begin: 0, end: 16) == "8000000000000000")
        let timestamp = UInt32(packet.substring(begin: 16, end: 24), radix: 16)!
        #expect(packet.substring(begin: 24, end: 48) == "000000000000000500000005")
        let sequenceNumber = UInt32(packet.substring(begin: 48, end: 56), radix: 16)!
        #expect(packet
            .substring(begin: 56, end: 176) ==
            """
            000005dc00002000ffffffff2ab1f77c000000000100007f000000000000\
            0000000000000001000300010503000000bf07d007d00005000134333231
            """)
        return (timestamp, sequenceNumber)
    }

    private func createConclusionHandshake() throws -> Data {
        return try Data(hexString: """
        800000000000000000000000000000000000000500000005000000000000\
        05dc00002000ffffffff2ab1f77c000000000100007f0000000000000000\
        000000000001000300010503000000bf07d007d00005000134333231
        """)
    }
}
