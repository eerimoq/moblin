import Foundation

protocol RTPJitterBufferDelegate: AnyObject {
    func jitterBuffer(_ buffer: RTPJitterBuffer<Self>, sequenced: RTPPacket)
}

final class RTPJitterBuffer<T: RTPJitterBufferDelegate> {
    weak var delegate: T?

    private var buffer: [UInt16: RTPPacket] = [:]
    private var expectedSequence: UInt16 = 0
    private let stalePacketCounts: Int = 4

    func append(_ packet: RTPPacket) {
        buffer[packet.sequenceNumber] = packet

        while let packet = buffer[expectedSequence] {
            delegate?.jitterBuffer(self, sequenced: packet)
            buffer.removeValue(forKey: expectedSequence)
            expectedSequence &+= 1
        }

        if stalePacketCounts <= buffer.count {
            expectedSequence &+= 1
        }
    }
}
