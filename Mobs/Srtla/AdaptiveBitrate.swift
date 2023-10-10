import Foundation

class AdaptiveBitrate {
    init() {
    }

    func outgoingPacket(packet _: Data, numberOfPacketsInFlight: Int) -> UInt32? {
        logger.debug("srtla: adaptive-bitrate: \(numberOfPacketsInFlight) data packets in flight")
        return nil
    }

    func incomingPacket(packet _: Data, numberOfPacketsInFlight: Int) -> UInt32? {
        return nil
    }
}
