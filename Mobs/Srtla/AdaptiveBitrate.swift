import Foundation

private let lowestBitrate = 100_000.0

class AdaptiveBitrate {
    private var targetBitrate: Double
    private var enabled: Bool
    private var currentBitrate: Double

    init(targetBitrate: UInt32, enabled: Bool) {
        self.targetBitrate = Double(targetBitrate)
        self.enabled = enabled
        currentBitrate = lowestBitrate
    }

    func outgoingPacket(packet _: Data, numberOfPacketsInFlight _: Int) -> UInt32? {
        return nil
    }

    func incomingPacket(packet: Data, numberOfPacketsInFlight: Int) -> UInt32? {
        if !enabled {
            return nil
        }
        var newBitrate: Double?
        if isControlPacket(packet: packet) {
            let type = getControlPacketType(packet: packet)
            if let type = SrtPacketType(rawValue: type) {
                switch type {
                case .nak:
                    newBitrate = max(currentBitrate * 0.8, lowestBitrate)
                default:
                    newBitrate = min(currentBitrate * 1.02, targetBitrate)
                }
            }
        }
        if let newBitrate, newBitrate != currentBitrate {
            currentBitrate = newBitrate
            logger.debug("""
            srtla: Bitrate: \(getCurrentBitrate()) (\(getTargetBitrate())), \
            Data packets in flight: \(numberOfPacketsInFlight)
            """)
            return getCurrentBitrate()
        } else {
            return nil
        }
    }

    func setTargetBitrate(value: UInt32) -> UInt32? {
        targetBitrate = Double(value)
        if !enabled {
            return value
        } else if currentBitrate > targetBitrate {
            currentBitrate = targetBitrate
            return getCurrentBitrate()
        } else {
            return nil
        }
    }

    func setAdaptiveBitrate(enabled: Bool) -> UInt32 {
        self.enabled = enabled
        currentBitrate = lowestBitrate
        return getCurrentBitrate()
    }

    private func getTargetBitrate() -> UInt32 {
        return UInt32(targetBitrate)
    }

    func getCurrentBitrate() -> UInt32 {
        if enabled {
            return UInt32(currentBitrate)
        } else {
            return getTargetBitrate()
        }
    }
}
