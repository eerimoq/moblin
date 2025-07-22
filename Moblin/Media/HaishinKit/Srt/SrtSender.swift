import Collections
import Foundation

private let srtDataPacketHeaderSize = 16
private let srtHandshakeVersion4: UInt32 = 4
private let srtHandshakeVersion5: UInt32 = 5
private let srtDestinationSocket: UInt32 = 0
private let srtMaximumTransmissionUnitSize: UInt32 = 1500
private let srtMaximumFlowWindowSizeInPackets: UInt32 = 8192
private let srtSocketId: UInt32 = 716_306_300
private let srtIpUdpHeaderSize: UInt64 = 28

private class SrtClock {
    static let startTime = ContinuousClock.now

    static func now(now: ContinuousClock.Instant) -> Int64 {
        return SrtClock.startTime.duration(to: now).microseconds
    }

    static func timestamp() -> UInt32 {
        return makeTimestamp(now: now(now: .now))
    }

    static func makeTimestamp(now: Int64) -> UInt32 {
        return UInt32(truncatingIfNeeded: now)
    }
}

private func createCommonControlPacketHeader(type: ControlPacketType,
                                             typeSpecificInformation: UInt32,
                                             timestamp: UInt32,
                                             destinationSocketId: UInt32) -> Data
{
    let writer = ByteWriter()
    writer.writeUInt16(0x8000 | type.rawValue)
    writer.writeUInt16(0)
    writer.writeUInt32(typeSpecificInformation)
    writer.writeUInt32(timestamp)
    writer.writeUInt32(destinationSocketId)
    return writer.data
}

private class AckAckPacket {
    var data: Data

    init() {
        data = createCommonControlPacketHeader(type: .ackack,
                                               typeSpecificInformation: 0,
                                               timestamp: 0,
                                               destinationSocketId: 0)
        // SRT 1.4.2 needs this...
        data += Data(count: 4)
    }

    func update(ackNumber: UInt32) {
        data.withUnsafeMutableBytes { pointer in
            pointer.writeUInt32(ackNumber, offset: 4)
            pointer.writeUInt32(SrtClock.timestamp(), offset: 8)
        }
    }

    func update(destinationSocketId: UInt32) {
        data.withUnsafeMutableBytes { pointer in
            pointer.writeUInt32(destinationSocketId, offset: 12)
        }
    }
}

private class KeepAlivePacket {
    var data: Data

    init() {
        data = createCommonControlPacketHeader(type: .keepAlive,
                                               typeSpecificInformation: 0,
                                               timestamp: 0,
                                               destinationSocketId: 0)
    }

    func update() {
        data.withUnsafeMutableBytes { pointer in
            pointer.writeUInt32(SrtClock.timestamp(), offset: 8)
        }
    }

    func update(destinationSocketId: UInt32) {
        data.withUnsafeMutableBytes { pointer in
            pointer.writeUInt32(destinationSocketId, offset: 12)
        }
    }
}

private enum SrtSenderState {
    case connecting
    case connected
    case disconnected
}

private struct CommonControlPacketHeader {
    var controlType: ControlPacketType
    var typeSpecificInformation: UInt32
    var timestamp: UInt32
    var destinationSrtSocketId: UInt32

    init(reader: ByteReader) throws {
        var value = try reader.readUInt16()
        value &= 0x7FFF
        guard let type = ControlPacketType(rawValue: value) else {
            throw "Unsupported packet type \(value)"
        }
        controlType = type
        _ = try reader.readUInt16()
        typeSpecificInformation = try reader.readUInt32()
        timestamp = try reader.readUInt32()
        destinationSrtSocketId = try reader.readUInt32()
    }
}

class SrtDataPacket {
    fileprivate var data: Data
    fileprivate var sequenceNumber: UInt32 = 0
    fileprivate var createdAt: ContinuousClock.Instant = SrtClock.startTime
    fileprivate var retransmittedAt: ContinuousClock.Instant?

    init(payload: UnsafeRawBufferPointer) {
        let packetSize = srtDataPacketHeaderSize + payload.count
        let packetPointer = UnsafeMutableRawPointer.allocate(byteCount: packetSize, alignment: 8)
        data = Data(
            bytesNoCopy: packetPointer,
            count: packetSize,
            deallocator: .custom { pointer, _ in pointer.deallocate() }
        )
        packetPointer.advanced(by: srtDataPacketHeaderSize).copyMemory(
            from: payload.baseAddress!,
            byteCount: payload.count
        )
    }

    fileprivate func setHeader(sequenceNumber: UInt32, now: ContinuousClock.Instant, destinationSrtSocketId: UInt32) {
        self.sequenceNumber = sequenceNumber
        createdAt = now
        data.withUnsafeMutableBytes { (pointer: UnsafeMutableRawBufferPointer) in
            pointer.writeUInt32(sequenceNumber, offset: 0)
            pointer.writeUInt32(0xE000_0001, offset: 4)
            pointer.writeUInt32(SrtClock.makeTimestamp(now: SrtClock.now(now: now)), offset: 8)
            pointer.writeUInt32(destinationSrtSocketId, offset: 12)
        }
    }

    fileprivate func setRetransmissionBit() {
        data[4] |= 0x4
    }
}

protocol SrtSenderDelegate: AnyObject {
    func srtSenderConnected()
    func srtSenderDisconnected()
    func srtSenderOutput(packet: Data)
}

private enum ControlPacketType: UInt16 {
    case handshake = 0
    case keepAlive = 1
    case ack = 2
    case nak = 3
    case shutdown = 5
    case ackack = 6
}

private enum HandshakeType: UInt32 {
    case conclusion = 0xFFFF_FFFF
    case induction = 0x0000_0001
}

class SrtSender {
    weak var delegate: SrtSenderDelegate?
    private var nextSequenceNumber: UInt32 = .random(in: 0 ..< 10000)
    private var peerDestinationSrtSocketId: UInt32 = 0
    private let streamId: String
    private var packetsToSend: Deque<SrtDataPacket> = []
    private var packetsInFlight: Deque<SrtDataPacket> = []
    private var packetsInFlightBySequenceNumber: [UInt32: SrtDataPacket] = [:]
    private var sequenceNumbersToRetransmit: OrderedSet<UInt32> = []
    private var state: SrtSenderState = .connecting
    private var performanceData: Atomic<SrtPerformanceData> = .init(.zero)
    private var numberOfBytesSent: UInt64 = 0
    private var latestNumberOfBytesSentTime = ContinuousClock.now
    private var pktRetransTotal: Int32 = 0
    private var pktRecvNakTotal: Int32 = 0
    private var pktSndDropTotal: Int32 = 0
    private var rttUs: UInt32 = 0
    private var mbpsSendRate: Double = 0.0
    private var latestOutputPacketsTime = ContinuousClock.now
    private let ackAckPacket = AckAckPacket()
    private let keepAlivePacket = KeepAlivePacket()
    private let latency: UInt16
    private var latestReceivedPacketTime = ContinuousClock.now
    private let packetsInFlightDropThreshold: ContinuousClock.Duration
    private let packetsToSendDropThreshold: ContinuousClock.Duration
    private let leakyBucketSmoothingTime: ContinuousClock.Duration

    init(streamId: String, latency: UInt16) {
        self.streamId = streamId
        self.latency = latency
        let latencyUs = 1000 * Int64(latency)
        packetsInFlightDropThreshold = .microseconds(latencyUs * 3 / 2)
        packetsToSendDropThreshold = .microseconds(latencyUs * 5 / 4)
        leakyBucketSmoothingTime = .milliseconds(min(Int(latency) / 10, 200))
    }

    func start() {
        srtlaClientQueue.async {
            self.latestReceivedPacketTime = .now
            self.setState(state: .connecting)
            self.outputPacket(packet: self.createInductionHandshakePacket())
        }
    }

    func stop() {
        srtlaClientQueue.async {
            self.setDisconnected()
        }
    }

    func newDataPacket(payload: UnsafeRawBufferPointer) -> SrtDataPacket {
        return SrtDataPacket(payload: payload)
    }

    func enqueue(packet: SrtDataPacket, now: ContinuousClock.Instant) {
        guard state == .connected else {
            return
        }
        packet.setHeader(sequenceNumber: getNextSequenceNumber(),
                         now: now,
                         destinationSrtSocketId: peerDestinationSrtSocketId)
        packetsToSend.append(packet)
    }

    func send(now: ContinuousClock.Instant) {
        guard state == .connected else {
            return
        }
        outputPackets(now: now)
        dropOldPackets(now: now)
        checkIfConnected(now: now)
    }

    func input(packet: Data) {
        latestReceivedPacketTime = .now
        do {
            try handleControlPacket(packet: packet, now: latestReceivedPacketTime)
        } catch {
            logger.info("srt-sender: Input error: \(error)")
        }
    }

    func getPerformanceData() -> SrtPerformanceData? {
        return performanceData.value
    }

    private func dropOldPackets(now: ContinuousClock.Instant) {
        while let packet = packetsInFlight.first, packet.createdAt.duration(to: now) > packetsInFlightDropThreshold {
            packetsInFlight.removeFirst()
            packetsInFlightBySequenceNumber.removeValue(forKey: packet.sequenceNumber)
            pktSndDropTotal += 1
        }
        while let packet = packetsToSend.first, packet.createdAt.duration(to: now) > packetsToSendDropThreshold {
            packetsToSend.removeFirst()
            pktSndDropTotal += 1
        }
    }

    private func setDisconnected() {
        guard state != .disconnected else {
            return
        }
        setState(state: .disconnected)
        delegate?.srtSenderDisconnected()
    }

    private func checkIfConnected(now: ContinuousClock.Instant) {
        guard latestReceivedPacketTime.duration(to: now) > .seconds(5) else {
            return
        }
        setDisconnected()
    }

    private func outputPackets(now: ContinuousClock.Instant) {
        guard latestOutputPacketsTime.duration(to: now) > .milliseconds(2) else {
            // logger.info("xxx output ignored")
            return
        }
        latestOutputPacketsTime = now
        var numberOfPacketsToSend = sequenceNumbersToRetransmit.count + packetsToSend.count
        // if let packet = packetsToSend.first, packet.createdAt.duration(to: now) > leakyBucketSmoothingTime {
        //     let count = sequenceNumbersToRetransmit.count + packetsToSend.count
        //     let duration = packet.createdAt.duration(to: now)
        //     logger.info("xxx are we falling behind? age: \(duration) packets: \(count)")
        // }
        numberOfPacketsToSend = max(numberOfPacketsToSend / 10, min(numberOfPacketsToSend, 10))
        // logger.info("xxx outputting \(numberOfPacketsToSend) packets")
        for _ in 0 ..< numberOfPacketsToSend {
            if retransmitPacketIfNeeded(now: now) {
                continue
            }
            guard let packet = packetsToSend.popFirst() else {
                break
            }
            sendPacket(packet: packet)
        }
        updatePerformanceData()
    }

    private func retransmitPacketIfNeeded(now: ContinuousClock.Instant) -> Bool {
        while !sequenceNumbersToRetransmit.isEmpty {
            let packetSequenceNumber = sequenceNumbersToRetransmit.removeFirst()
            guard let packet = packetsInFlightBySequenceNumber[packetSequenceNumber] else {
                continue
            }
            if let retransmittedAt = packet.retransmittedAt, retransmittedAt.duration(to: now) < .microseconds(rttUs) {
                continue
            }
            // logger.info("xxx RETX  \(packetSequenceNumber) RTT: \(rttUs)")
            packet.retransmittedAt = now
            packet.setRetransmissionBit()
            pktRetransTotal += 1
            outputPacket(packet: packet.data)
            return true
        }
        return false
    }

    private func sendPacket(packet: SrtDataPacket) {
        outputPacket(packet: packet.data)
        packetsInFlight.append(packet)
        packetsInFlightBySequenceNumber[packet.sequenceNumber] = packet
    }

    private func outputPacket(packet: Data) {
        delegate?.srtSenderOutput(packet: packet)
        numberOfBytesSent += UInt64(packet.count) + srtIpUdpHeaderSize
    }

    private func setState(state: SrtSenderState) {
        guard state != self.state else {
            return
        }
        logger.info("srt-sender: Job state change \(self.state) -> \(state)")
        self.state = state
    }

    private func getNextSequenceNumber() -> UInt32 {
        defer {
            nextSequenceNumber += 1
        }
        return nextSequenceNumber
    }

    private func createInductionHandshakePacket() -> Data {
        let writer = ByteWriter()
        writer.writeBytes(createCommonControlPacketHeader(type: .handshake,
                                                          typeSpecificInformation: 0,
                                                          timestamp: SrtClock.timestamp(),
                                                          destinationSocketId: srtDestinationSocket))
        writer.writeUInt32(srtHandshakeVersion4)
        writer.writeUInt16(0)
        writer.writeUInt16(2)
        writer.writeUInt32(nextSequenceNumber)
        writer.writeUInt32(srtMaximumTransmissionUnitSize)
        writer.writeUInt32(srtMaximumFlowWindowSizeInPackets)
        writer.writeUInt32(HandshakeType.induction.rawValue)
        writer.writeUInt32(srtSocketId)
        writer.writeUInt32(0)
        writer.writeBytes(Data([1, 0, 0, 127,
                                0, 0, 0, 0,
                                0, 0, 0, 0,
                                0, 0, 0, 0]))
        return writer.data
    }

    private func createConclusionHandshakePacket(peerSocketId: UInt32, synCookie: UInt32) -> Data {
        let writer = ByteWriter()
        writer.writeBytes(createCommonControlPacketHeader(type: .handshake,
                                                          typeSpecificInformation: 0,
                                                          timestamp: SrtClock.timestamp(),
                                                          destinationSocketId: srtDestinationSocket))
        writer.writeUInt32(srtHandshakeVersion5)
        writer.writeUInt16(0)
        writer.writeUInt16(5)
        writer.writeUInt32(nextSequenceNumber)
        writer.writeUInt32(srtMaximumTransmissionUnitSize)
        writer.writeUInt32(srtMaximumFlowWindowSizeInPackets)
        writer.writeUInt32(HandshakeType.conclusion.rawValue)
        writer.writeUInt32(peerSocketId)
        writer.writeUInt32(synCookie)
        writer.writeBytes(Data([1, 0, 0, 127,
                                0, 0, 0, 0,
                                0, 0, 0, 0,
                                0, 0, 0, 0]))
        writer.writeUInt16(1)
        writer.writeUInt16(3)
        writer.writeUInt32(0x0001_0503)
        writer.writeUInt32(0xBF)
        writer.writeUInt16(latency)
        writer.writeUInt16(latency)
        writer.writeUInt16(5)
        let streamId = encodeStreamId(streamId: streamId)
        writer.writeUInt16(UInt16(streamId.count / 4))
        writer.writeBytes(streamId)
        return writer.data
    }

    private func encodeStreamId(streamId: String) -> Data {
        var streamId = streamId.utf8Data
        let paddingLength = 4 - (streamId.count % 4)
        if paddingLength < 4 {
            streamId += Data(repeating: 0, count: paddingLength)
        }
        for offset in stride(from: 0, to: streamId.count, by: 4) {
            streamId[offset ..< offset + 4] = Data(streamId[offset ..< offset + 4].reversed())
        }
        return streamId
    }

    private func handleControlPacket(packet: Data, now: ContinuousClock.Instant) throws {
        let reader = ByteReader(data: packet)
        let commonHeader = try CommonControlPacketHeader(reader: reader)
        switch commonHeader.controlType {
        case .handshake:
            try handleHandshakePacket(reader: reader)
        case .keepAlive:
            handleKeepAlivePacket()
        case .ack:
            try handleAckPacket(commonHeader: commonHeader, reader: reader, now: now)
        case .nak:
            try handleNakPacket(reader: reader)
        case .shutdown:
            try handleShutdownPacket()
        case .ackack:
            try handleAckAckPacket()
        }
        outputPackets(now: now)
    }

    private func handleHandshakePacket(reader: ByteReader) throws {
        _ = try reader.readUInt32()
        _ = try reader.readUInt16()
        _ = try reader.readUInt16()
        _ = try reader.readUInt32()
        _ = try reader.readUInt32()
        _ = try reader.readUInt32()
        guard let handshakeType = try HandshakeType(rawValue: reader.readUInt32()) else {
            throw "Unsupported handshake type"
        }
        let peerSocketId = try reader.readUInt32()
        let synCookie = try reader.readUInt32()
        _ = try reader.readBytes(16)
        switch handshakeType {
        case .induction:
            handleHandshakeInduction(peerSocketId: peerSocketId, synCookie: synCookie)
        case .conclusion:
            handleHandshakeConclusion(peerSocketId: peerSocketId)
        }
    }

    private func handleHandshakeInduction(peerSocketId: UInt32, synCookie: UInt32) {
        outputPacket(packet: createConclusionHandshakePacket(
            peerSocketId: peerSocketId,
            synCookie: synCookie
        ))
    }

    private func handleHandshakeConclusion(peerSocketId: UInt32) {
        peerDestinationSrtSocketId = peerSocketId
        ackAckPacket.update(destinationSocketId: peerSocketId)
        keepAlivePacket.update(destinationSocketId: peerSocketId)
        setState(state: .connected)
        delegate?.srtSenderConnected()
    }

    private func handleKeepAlivePacket() {
        keepAlivePacket.update()
        outputPacket(packet: keepAlivePacket.data)
    }

    private func handleAckPacket(commonHeader: CommonControlPacketHeader,
                                 reader: ByteReader,
                                 now: ContinuousClock.Instant) throws
    {
        let lastAcknowledgedPacketSequenceNumber = try reader.readUInt32()
        removeAckedPackets(lastAcknowledgedPacketSequenceNumber)
        if commonHeader.typeSpecificInformation != 0 {
            rttUs = try reader.readUInt32()
            updateSendRate(now: now)
            updatePerformanceData()
            ackAckPacket.update(ackNumber: commonHeader.typeSpecificInformation)
            outputPacket(packet: ackAckPacket.data)
        }
    }

    private func updatePerformanceData() {
        performanceData.mutate {
            $0.pktRetransTotal = pktRetransTotal
            $0.pktRecvNakTotal = pktRecvNakTotal
            $0.pktSndDropTotal = pktSndDropTotal
            $0.pktFlightSize = Int32(packetsInFlight.count)
            $0.msRtt = Double(rttUs) / 1000
            $0.mbpsSendRate = mbpsSendRate
        }
    }

    private func updateSendRate(now: ContinuousClock.Instant) {
        let duration = latestNumberOfBytesSentTime.duration(to: now)
        guard duration > .milliseconds(200) else {
            return
        }
        latestNumberOfBytesSentTime = now
        let latestMbpsSendRate = Double(8 * numberOfBytesSent) / duration.seconds / 1_000_000
        numberOfBytesSent = 0
        mbpsSendRate = 0.7 * mbpsSendRate + 0.3 * latestMbpsSendRate
    }

    private func removeAckedPackets(_ lastAcknowledgedPacketSequenceNumber: UInt32) {
        if let lastAcknowledgedPacketIndex = packetsInFlight.firstIndex(where: { !isSrtSnAcked(
            sn: $0.sequenceNumber,
            ackSn: lastAcknowledgedPacketSequenceNumber
        ) }) {
            for index in 0 ..< lastAcknowledgedPacketIndex {
                packetsInFlightBySequenceNumber.removeValue(forKey: packetsInFlight[index].sequenceNumber)
            }
            packetsInFlight.removeFirst(lastAcknowledgedPacketIndex)
        }
    }

    private func handleNakPacket(reader: ByteReader) throws {
        // logger.info("xxx NAK packet")
        while let sequenceNumber = try? reader.readUInt32() {
            if isSrtSnRange(sn: sequenceNumber) {
                let upToNakSequenceNumber = try reader.readUInt32()
                for sequenceNumber in stride(from: sequenceNumber & 0x7FFF_FFFF,
                                             through: upToNakSequenceNumber,
                                             by: 1)
                {
                    // logger.info("xxx   NAK-1 \(sequenceNumber)")
                    guard sequenceNumbersToRetransmit.count < 1000 else {
                        logger.info("xxx   Too many NAKs")
                        return
                    }
                    sequenceNumbersToRetransmit.append(sequenceNumber)
                }
            } else {
                // logger.info("xxx   NAK-2 \(sequenceNumber)")
                guard sequenceNumbersToRetransmit.count < 1000 else {
                    logger.info("xxx   Too many NAKs")
                    return
                }
                sequenceNumbersToRetransmit.append(sequenceNumber)
            }
        }
        pktRecvNakTotal += 1
    }

    private func handleShutdownPacket() throws {
        throw "Got shutdown packet"
    }

    private func handleAckAckPacket() throws {
        throw "Got ack ack packet"
    }
}
