import Foundation

final class RtmpHandshake {
    static let sigSize: Int = 1536
    private static let protocolVersion: UInt8 = 3
    private var timestamp: TimeInterval = 0

    func createC0C1Packet() -> Data {
        let packet = ByteArray()
            .writeUInt8(RtmpHandshake.protocolVersion)
            .writeInt32(Int32(timestamp))
            .writeBytes(Data([0x00, 0x00, 0x00, 0x00]))
        for _ in 0 ..< RtmpHandshake.sigSize - 8 {
            packet.writeUInt8(UInt8.random(in: 0 ... UInt8.max))
        }
        return packet.data
    }

    func createC2Packet(_ s0s1packet: Data) -> Data {
        ByteArray()
            .writeBytes(s0s1packet.subdata(in: 1 ..< 5))
            .writeInt32(Int32(Date().timeIntervalSince1970 - timestamp))
            .writeBytes(s0s1packet.subdata(in: 9 ..< RtmpHandshake.sigSize + 1))
            .data
    }
}
