import Foundation
@testable import Moblin
import Testing

private class ModelMock {
    private let connected = MessageQueue<Void>()
    private let disconnected = MessageQueue<Void>()
    private let packets = MessageQueue<String>()
    private let dataPackets = Atomic<[Data]>([])

    func waitForConnected() async {
        await connected.get()
    }

    func waitForDisconnected() async {
        await disconnected.get()
    }

    func waitForPacket() async -> String {
        await packets.get()
    }

    func takeDataPackets() -> [Data] {
        dataPackets.mutate {
            let packets = $0
            $0.removeAll()
            return packets
        }
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
        if packet[0] & 0x80 == 0 {
            dataPackets.mutate { $0.append(packet) }
        }
        packets.put(packet.hexString())
    }
}

struct SrtSenderSuite {
    @Test
    func connectDisconnect() async throws {
        let (sender, model) = try await connectSender(experimental: false)
        sender.send(now: .now.advanced(by: .seconds(6)))
        await model.waitForDisconnected()
    }

    @Test
    func retransmitInPriorityOrder() async throws {
        let (sender, model) = try await connectSender(experimental: true)
        var now = ContinuousClock.now
        for containsAudio in [false, true, false, true] {
            enqueuePacket(sender: sender, containsAudio: containsAudio, now: now)
        }
        sendPackets(sender: sender, now: &now, count: 10)
        let sequenceNumbers = model.takeDataPackets().map { getSrtSequenceNumber(packet: $0) }
        try #require(sequenceNumbers.count == 4)

        sender.input(packet: createControlPacket(type: 3, values: [
            sequenceNumbers[2], sequenceNumbers[3], sequenceNumbers[0], sequenceNumbers[1],
            sequenceNumbers[2], sequenceNumbers[3],
        ]), now: now)
        sendPackets(sender: sender, now: &now, count: 10)
        let retransmittedPackets = model.takeDataPackets()
        #expect(retransmittedPackets.map { getSrtSequenceNumber(packet: $0) } == [
            sequenceNumbers[3], sequenceNumbers[1], sequenceNumbers[2], sequenceNumbers[0],
        ])
        #expect(retransmittedPackets.allSatisfy { $0[4] & 0x04 != 0 })
        #expect(sender.getPerformanceData()?.pktRetransTotal == 4)

        sender.input(packet: createControlPacket(type: 3, values: [sequenceNumbers[2]]), now: now)
        sendPackets(sender: sender, now: &now)
        #expect(model.takeDataPackets().map { getSrtSequenceNumber(packet: $0) } == [sequenceNumbers[2]])
        #expect(sender.getPerformanceData()?.pktRetransTotal == 5)
        #expect(sender.getPerformanceData()?.pktRecvNakTotal == 2)
    }

    @Test
    func retransmitAfterRttSkip() async throws {
        let (sender, model) = try await connectSender(experimental: false)
        var now = ContinuousClock.now
        enqueuePacket(sender: sender, containsAudio: false, now: now)
        sendPackets(sender: sender, now: &now)
        let packet = try #require(model.takeDataPackets().first)
        let sequenceNumber = getSrtSequenceNumber(packet: packet)
        sender.input(packet: createControlPacket(
            type: 2,
            information: 1,
            values: [sequenceNumber, 2_000_000]
        ), now: now)
        let nak = createControlPacket(type: 3, values: [sequenceNumber])
        sender.input(packet: nak, now: now)
        sendPackets(sender: sender, now: &now)
        #expect(model.takeDataPackets().map { getSrtSequenceNumber(packet: $0) } == [sequenceNumber])

        sender.input(packet: nak, now: now)
        sendPackets(sender: sender, now: &now)
        #expect(model.takeDataPackets().isEmpty)
        #expect(sender.getPerformanceData()?.pktRetransTotal == 1)

        now = now.advanced(by: .seconds(2))
        sender.send(now: now)
        sender.input(packet: nak, now: now)
        sendPackets(sender: sender, now: &now)
        #expect(model.takeDataPackets().map { getSrtSequenceNumber(packet: $0) } == [sequenceNumber])
        #expect(sender.getPerformanceData()?.pktRetransTotal == 2)
        #expect(sender.getPerformanceData()?.pktRecvNakTotal == 3)
    }

    @Test
    func limitPendingRetransmissions() async throws {
        let (sender, model) = try await connectSender(experimental: true)
        var now = ContinuousClock.now
        for index in 0 ..< 1001 {
            enqueuePacket(sender: sender, containsAudio: index % 2 == 1, now: now)
        }
        sendPackets(sender: sender, now: &now, count: 100)
        let sequenceNumbers = model.takeDataPackets().map { getSrtSequenceNumber(packet: $0) }
        try #require(sequenceNumbers.count == 1001)
        sender.input(packet: createControlPacket(type: 3, values: [
            sequenceNumbers[0] | 0x8000_0000, sequenceNumbers[1000],
        ]), now: now)
        sendPackets(sender: sender, now: &now, count: 200)
        let expected = stride(from: 1, to: 1000, by: 2).map { sequenceNumbers[$0] }
            + stride(from: 0, to: 1000, by: 2).map { sequenceNumbers[$0] }
        #expect(model.takeDataPackets().map { getSrtSequenceNumber(packet: $0) } == expected)
        #expect(sender.getPerformanceData()?.pktRetransTotal == 1000)
        #expect(sender.getPerformanceData()?.pktRecvNakTotal == 0)

        sender.input(packet: createControlPacket(type: 3, values: [sequenceNumbers[1000]]), now: now)
        sendPackets(sender: sender, now: &now)
        #expect(model.takeDataPackets().map { getSrtSequenceNumber(packet: $0) } == [sequenceNumbers[1000]])
        #expect(sender.getPerformanceData()?.pktRetransTotal == 1001)
        #expect(sender.getPerformanceData()?.pktRecvNakTotal == 1)
    }

    private func enqueuePacket(sender: SrtSender, containsAudio: Bool, now: ContinuousClock.Instant) {
        Data([0]).withUnsafeBytes {
            let packet = sender.newDataPacket(payload: $0)
            packet.containsAudio = containsAudio
            sender.enqueue(packet: packet, now: now)
        }
    }

    private func sendPackets(sender: SrtSender, now: inout ContinuousClock.Instant, count: Int = 1) {
        for _ in 0 ..< count {
            now = now.advanced(by: .milliseconds(3))
            sender.send(now: now)
        }
    }

    private func createControlPacket(type: UInt16, information: UInt32 = 0, values: [UInt32]) -> Data {
        let writer = ByteWriter()
        writer.writeUInt16(0x8000 | type)
        writer.writeUInt16(0)
        writer.writeUInt32(information)
        writer.writeUInt32(0)
        writer.writeUInt32(0)
        for value in values {
            writer.writeUInt32(value)
        }
        return writer.data
    }

    private func connectSender(experimental: Bool) async throws -> (SrtSender, ModelMock) {
        let sender = SrtSender(streamId: "1234", latency: 2000, experimental: experimental)
        let model = ModelMock()
        sender.delegate = model
        sender.start()
        _ = await checkInductionHandshake(packet: model.waitForPacket())
        try sender.input(packet: createInductionHandshake())
        _ = await checkConclusionHandshake(packet: model.waitForPacket())
        try sender.input(packet: createConclusionHandshake())
        await model.waitForConnected()
        return (sender, model)
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
        try Data(hexString: """
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
        try Data(hexString: """
        800000000000000000000000000000000000000500000005000000000000\
        05dc00002000ffffffff2ab1f77c000000000100007f0000000000000000\
        000000000001000300010503000000bf07d007d00005000134333231
        """)
    }
}
