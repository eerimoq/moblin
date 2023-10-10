import Foundation

class AdaptiveBitrate {
    private var targetBitrate: UInt32

    init(targetBitrate: UInt32) {
        self.targetBitrate = targetBitrate
    }

    func outgoingPacket(packet _: Data, numberOfPacketsInFlight: Int) -> UInt32? {
        logger
            .debug(
                "srtla: Target bitrate: \(targetBitrate), Data packets in flight: \(numberOfPacketsInFlight)"
            )
        return nil
    }

    func incomingPacket(packet _: Data, numberOfPacketsInFlight _: Int) -> UInt32? {
        return nil
    }

    func setTargetBitrate(value: UInt32) {
        targetBitrate = value
    }
}
