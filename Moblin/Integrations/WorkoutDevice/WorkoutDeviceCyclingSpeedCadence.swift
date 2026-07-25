@preconcurrency import CoreBluetooth
import Foundation

let workoutDeviceCyclingSpeedCadenceServiceId = CBUUID(string: "1816")
let workoutDeviceCscMeasurementCharacteristicId = CBUUID(string: "2A5B")

private let measurementWheelRevolutionDataFlagIndex = 0
private let measurementCrankRevolutionDataFlagIndex = 1

private let averageSampleCount = 3

private struct CscMeasurement {
    // periphery:ignore
    var cumulativeWheelRevolutions: UInt32?
    // periphery:ignore
    var lastWheelEventTime: UInt16?
    var cumulativeCrankRevolutions: UInt16?
    var lastCrankEventTime: UInt16?

    init(value: Data) throws {
        let reader = ByteReader(data: value)
        let flags = try reader.readUInt8()
        if flags.isBitSet(index: measurementWheelRevolutionDataFlagIndex) {
            cumulativeWheelRevolutions = try reader.readUInt32Le()
            lastWheelEventTime = try reader.readUInt16Le()
        }
        if flags.isBitSet(index: measurementCrankRevolutionDataFlagIndex) {
            cumulativeCrankRevolutions = try reader.readUInt16Le()
            lastCrankEventTime = try reader.readUInt16Le()
        }
    }
}

private class AverageCadenceCalculator {
    private var values = Array(repeating: 0, count: averageSampleCount)
    private var nextIndex = 0

    func update(value: Int) {
        values[nextIndex] = value
        nextIndex += 1
        nextIndex %= averageSampleCount
    }

    func averageIgnoreZeros() -> Int {
        let numberOfNonZeroValues = values.filter { $0 != 0 }.count
        guard numberOfNonZeroValues > 0 else {
            return 0
        }
        return values.reduce(0, +) / numberOfNonZeroValues
    }
}

class WorkoutDeviceCyclingSpeedCadence {
    private var measurementCharacteristic: CBCharacteristic?
    private var previousCrankRevolutions: UInt16?
    private var previousCrankRevolutionsTime: UInt16?
    private var averageCadence = AverageCadenceCalculator()
    private var latestAverageCadenceUpdateTime = ContinuousClock.now

    func reset() {
        measurementCharacteristic = nil
        previousCrankRevolutions = nil
        previousCrankRevolutionsTime = nil
    }

    func setMeasurementCharacteristic(_ characteristic: CBCharacteristic) {
        measurementCharacteristic = characteristic
    }

    func isAnyCharacteristicDiscovered() -> Bool {
        measurementCharacteristic != nil
    }

    func handleMeasurement(value: Data) throws -> Int {
        let measurement = try CscMeasurement(value: value)
        var cadence = -1.0
        if let revolutions = measurement.cumulativeCrankRevolutions,
           let time = measurement.lastCrankEventTime
        {
            if let previousCrankRevolutions, let previousCrankRevolutionsTime {
                var deltaRevolutions = Int(revolutions) - Int(previousCrankRevolutions)
                if deltaRevolutions < 0 {
                    deltaRevolutions += 65536
                }
                var deltaTime = Int(time) - Int(previousCrankRevolutionsTime)
                if deltaTime < 0 {
                    deltaTime += 65536
                }
                let deltaTimeSeconds = Double(deltaTime) / 1024
                if deltaTimeSeconds > 0 {
                    cadence = 60 * Double(deltaRevolutions) / deltaTimeSeconds
                    cadence = min(cadence, 10000)
                }
            }
            previousCrankRevolutions = revolutions
            previousCrankRevolutionsTime = time
        }
        let now = ContinuousClock.now
        if cadence != -1.0 {
            averageCadence.update(value: Int(cadence))
            latestAverageCadenceUpdateTime = now
        } else if latestAverageCadenceUpdateTime.duration(to: now) > .seconds(3) {
            averageCadence.update(value: 0)
        }
        return averageCadence.averageIgnoreZeros()
    }
}
