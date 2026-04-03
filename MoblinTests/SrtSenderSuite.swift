import Foundation
@testable import Moblin
import Testing

private class ModelMock {
    private let connected = MessageQueue<Void>()
    private let disconnected = MessageQueue<Void>()
    private let packets = MessageQueue<String>()
    private var connectedCount = Atomic(0)
    private var disconnectedCount = Atomic(0)
    private var packetCount = Atomic(0)

    func waitForConnected() async {
        await connected.get()
    }

    func waitForDisconnected() async {
        await disconnected.get()
    }

    func waitForPacket() async -> String {
        return await packets.get()
    }

    func getConnectedCount() -> Int {
        return connectedCount.value
    }

    func getDisconnectedCount() -> Int {
        return disconnectedCount.value
    }

    func getPacketCount() -> Int {
        return packetCount.value
    }
}

extension ModelMock: SrtSenderDelegate {
    func srtSenderConnected() {
        connectedCount.mutate {
            $0 += 1
        }
        connected.put(())
    }

    func srtSenderDisconnected() {
        disconnectedCount.mutate {
            $0 += 1
        }
        disconnected.put(())
    }

    func srtSenderOutput(packet: Data) {
        packetCount.mutate {
            $0 += 1
        }
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

    @Test
    func duplicateInductionIsIgnored() async throws {
        let sender = SrtSender(streamId: "1234", latency: 2000)
        let model = ModelMock()
        sender.delegate = model
        sender.start()
        _ = checkInductionHandshake(packet: await model.waitForPacket())
        try sender.input(packet: createInductionHandshake())
        _ = checkConclusionHandshake(packet: await model.waitForPacket())
        #expect(model.getPacketCount() == 2)
        try sender.input(packet: createInductionHandshake())
        #expect(model.getPacketCount() == 2)
        #expect(model.getConnectedCount() == 0)
        try sender.input(packet: createConclusionHandshake())
        #expect(model.getConnectedCount() == 1)
        try sender.input(packet: createInductionHandshake())
        #expect(model.getPacketCount() == 2)
        #expect(model.getConnectedCount() == 1)
    }

    @Test
    func duplicateConclusionIsIgnored() async throws {
        let sender = SrtSender(streamId: "1234", latency: 2000)
        let model = ModelMock()
        sender.delegate = model
        sender.start()
        _ = checkInductionHandshake(packet: await model.waitForPacket())
        try sender.input(packet: createInductionHandshake())
        _ = checkConclusionHandshake(packet: await model.waitForPacket())
        try sender.input(packet: createConclusionHandshake())
        #expect(model.getConnectedCount() == 1)
        #expect(model.getDisconnectedCount() == 0)
        let packetCount = model.getPacketCount()
        try sender.input(packet: createConclusionHandshake())
        #expect(model.getConnectedCount() == 1)
        #expect(model.getDisconnectedCount() == 0)
        #expect(model.getPacketCount() == packetCount)
    }

    @Test
    func conclusionBeforeInductionIsIgnored() async throws {
        let sender = SrtSender(streamId: "1234", latency: 2000)
        let model = ModelMock()
        sender.delegate = model
        sender.start()
        _ = checkInductionHandshake(packet: await model.waitForPacket())
        try sender.input(packet: createConclusionHandshake())
        #expect(model.getConnectedCount() == 0)
        #expect(model.getPacketCount() == 1)
        try sender.input(packet: createInductionHandshake())
        _ = checkConclusionHandshake(packet: await model.waitForPacket())
        #expect(model.getPacketCount() == 2)
        try sender.input(packet: createConclusionHandshake())
        #expect(model.getConnectedCount() == 1)
    }

    @Test
    func wrongCookieConclusionIsIgnored() async throws {
        let sender = SrtSender(streamId: "1234", latency: 2000)
        let model = ModelMock()
        sender.delegate = model
        sender.start()
        _ = checkInductionHandshake(packet: await model.waitForPacket())
        try sender.input(packet: createInductionHandshake())
        _ = checkConclusionHandshake(packet: await model.waitForPacket())
        try sender.input(packet: createConclusionHandshake(synCookie: 1))
        #expect(model.getConnectedCount() == 0)
        #expect(model.getPacketCount() == 2)
        try sender.input(packet: createConclusionHandshake())
        #expect(model.getConnectedCount() == 1)
    }

    @Test
    func ignoredStaleControlDoesNotPreventDisconnect() async throws {
        let sender = SrtSender(streamId: "1234", latency: 2000)
        let model = ModelMock()
        sender.delegate = model
        sender.start()
        _ = checkInductionHandshake(packet: await model.waitForPacket())
        try sender.input(packet: createInductionHandshake())
        _ = checkConclusionHandshake(packet: await model.waitForPacket())
        try sender.input(packet: createConclusionHandshake())
        #expect(model.getConnectedCount() == 1)
        try await Task.sleep(nanoseconds: 1_500_000_000)
        let packetCount = model.getPacketCount()
        try sender.input(packet: createInductionHandshake())
        #expect(model.getPacketCount() == packetCount)
        sender.send(now: .now.advanced(by: .seconds(4)))
        await model.waitForDisconnected()
    }

    private func checkInductionHandshake(packet: String) -> (UInt32, UInt32) {
        #expect(packet.count == 128)
        #expect(packet.substring(begin: 0, end: 16) == "8000000000000000")
        let timestamp = UInt32(packet.substring(begin: 16, end: 24), radix: 16)!
        #expect(packet.substring(begin: 24, end: 48) == "000000000000000400000002")
        let sequenceNumber = UInt32(packet.substring(begin: 48, end: 56), radix: 16)!
        #expect(packet.substring(begin: 56, end: 80) == "000005dc0000200000000001")
        #expect(packet.substring(begin: 88, end: 128) == "000000000100007f000000000000000000000000")
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

    private func createConclusionHandshake(synCookie: UInt32 = 0) throws -> Data {
        return try Data(hexString: """
        800000000000000000000000000000000000000500000005000000000000\
        05dc00002000ffffffff2ab1f77c\(String(format: "%08x", synCookie))0100007f0000000000000000\
        000000000001000300010503000000bf07d007d00005000134333231
        """)
    }
}
