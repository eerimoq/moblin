import Foundation

private let averageSampleCount = 3

class WorkoutDeviceAverageCalculator {
    private var values = Array(repeating: 0.0, count: averageSampleCount)
    private var nextIndex = 0

    func reset() {
        values = Array(repeating: 0.0, count: averageSampleCount)
        nextIndex = 0
    }

    func update(value: Double) {
        values[nextIndex] = value
        nextIndex += 1
        nextIndex %= averageSampleCount
    }

    func average() -> Double {
        values.reduce(0, +) / Double(averageSampleCount)
    }

    func averageIgnoreZeros() -> Double {
        let nonZeroValues = values.filter { $0 != 0 }
        guard !nonZeroValues.isEmpty else {
            return 0
        }
        return nonZeroValues.reduce(0, +) / Double(nonZeroValues.count)
    }
}

class WorkoutDeviceCrankCadence {
    private var previousRevolutions: UInt16?
    private var previousRevolutionsTime: UInt16?
    private let averageCadence = WorkoutDeviceAverageCalculator()
    private var latestAverageCadenceUpdateTime = ContinuousClock.now

    func reset() {
        previousRevolutions = nil
        previousRevolutionsTime = nil
        averageCadence.reset()
    }

    func update(revolutions: UInt16?, time: UInt16?, now: ContinuousClock.Instant) -> Int {
        var cadence = -1.0
        if let revolutions, let time {
            if let previousRevolutions, let previousRevolutionsTime {
                var deltaRevolutions = Int(revolutions) - Int(previousRevolutions)
                if deltaRevolutions < 0 {
                    deltaRevolutions += 65536
                }
                var deltaTime = Int(time) - Int(previousRevolutionsTime)
                if deltaTime < 0 {
                    deltaTime += 65536
                }
                let deltaTimeSeconds = Double(deltaTime) / 1024
                if deltaTimeSeconds > 0 {
                    cadence = 60 * Double(deltaRevolutions) / deltaTimeSeconds
                    cadence = min(cadence, 10000)
                }
            }
            previousRevolutions = revolutions
            previousRevolutionsTime = time
        }
        if cadence != -1.0 {
            averageCadence.update(value: cadence)
            latestAverageCadenceUpdateTime = now
        } else if latestAverageCadenceUpdateTime.duration(to: now) > .seconds(3) {
            averageCadence.update(value: 0)
        }
        return Int(averageCadence.averageIgnoreZeros())
    }
}
