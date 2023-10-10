import Foundation

class AdaptiveBitrate {
    private var targetBitrate: UInt32?

    init(targetBitrate: UInt32) {
        self.targetBitrate = targetBitrate
    }

    // Returns wanted bitrate, or nil if no change is needed.
    func outgoingPacket(packet: Data, numberOfPacketsInFlight: Int) -> UInt32? {
        if isControlPacket(packet: packet) {
            let type = getControlPacketType(packet: packet)
            if let type = SrtPacketType(rawValue: type) {
                switch type {
                case .nak:
                    logger.info("NAK")
                default:
                    break
                }
            }
        }
        logger
            .debug(
                "srtla: Target bitrate: \(targetBitrate), Data packets in flight: \(numberOfPacketsInFlight)"
            )
        defer {
            targetBitrate = nil
        }
        return targetBitrate
    }

    // Returns wanted bitrate, or nil if no change is needed.
    func incomingPacket(packet _: Data, numberOfPacketsInFlight _: Int) -> UInt32? {
        return nil
    }

    func setTargetBitrate(value: UInt32) {
        logger.debug("set target \(value)")
        targetBitrate = value
    }
}
