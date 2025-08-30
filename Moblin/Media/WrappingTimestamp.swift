import AVFoundation

class WrappingTimestamp {
    private let name: String
    private let maximumTimestamp: CMTime
    private let halfMaximumTimestamp: CMTime
    private var highTimestamp = CMTime(seconds: 0.0)
    private var previousTimestamp = CMTime(seconds: 0.0)

    init(name: String, maximumTimestamp: CMTime) {
        self.name = name
        self.maximumTimestamp = maximumTimestamp
        halfMaximumTimestamp = CMTime(value: maximumTimestamp.value / 2, timescale: maximumTimestamp.timescale)
    }

    func update(_ timestamp: CMTime) -> CMTime {
        if timestamp >= previousTimestamp {
            if timestamp - previousTimestamp < halfMaximumTimestamp {
                defer {
                    previousTimestamp = timestamp
                }
                return highTimestamp + timestamp
            } else {
                return highTimestamp - maximumTimestamp + timestamp
            }
        } else {
            defer {
                previousTimestamp = timestamp
            }
            if previousTimestamp - timestamp > halfMaximumTimestamp {
                logger.info("Wrapping timestamp \(name) just wrapped around.")
                highTimestamp = highTimestamp + maximumTimestamp
            }
            return highTimestamp + timestamp
        }
    }
}
