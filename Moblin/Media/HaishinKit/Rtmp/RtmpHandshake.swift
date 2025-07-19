import Foundation

enum RtmpHandshake {
    static let sigSize = 1536
    private static let protocolVersion: UInt8 = 3
    private static let timestamp: TimeInterval = 0

    static func createC0C1Packet() -> Data {
        let writer = ByteWriter()
        writer.writeUInt8(RtmpHandshake.protocolVersion)
        writer.writeInt32(Int32(timestamp))
        writer.writeBytes(Data([0x00, 0x00, 0x00, 0x00]))
        for _ in 0 ..< RtmpHandshake.sigSize - 8 {
            writer.writeUInt8(UInt8.random(in: 0 ... UInt8.max))
        }
        return writer.data
    }

    static func createC2Packet(_ s0s1packet: Data) -> Data {
        let writer = ByteWriter()
        writer.writeBytes(s0s1packet.subdata(in: 1 ..< 5))
        writer.writeInt32(Int32(Date().timeIntervalSince1970 - timestamp))
        writer.writeBytes(s0s1packet.subdata(in: 9 ..< RtmpHandshake.sigSize + 1))
        return writer.data
    }
}
