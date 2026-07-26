@preconcurrency import CoreBluetooth
import Foundation

let workoutDeviceCyclingSpeedCadenceServiceId = CBUUID(string: "1816")
let workoutDeviceCscMeasurementCharacteristicId = CBUUID(string: "2A5B")

/// Default 700×25c tire circumference (Cateye / common bike computer default).
let workoutDeviceDefaultWheelCircumferenceMeters = 2.105

private let measurementWheelRevolutionDataFlagIndex = 0
private let measurementCrankRevolutionDataFlagIndex = 1

private let averageSampleCount = 3

private struct CscMeasurement {
    var cumulativeWheelRevolutions: UInt32?
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

private class AverageIntCalculator {
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

private class AverageDoubleCalculator {
    private var values = Array(repeating: 0.0, count: averageSampleCount)
    private var nextIndex = 0

    func update(value: Double) {
        values[nextIndex] = value
        nextIndex += 1
        nextIndex %= averageSampleCount
    }

    func averageIgnoreZeros() -> Double {
        let nonZeroValues = values.filter { $0 != 0 }
        guard !nonZeroValues.isEmpty else {
            return 0
        }
        return nonZeroValues.reduce(0, +) / Double(nonZeroValues.count)
    }
}

class WorkoutDeviceCyclingSpeedCadence {
    private var measurementCharacteristic: CBCharacteristic?
    private var previousCrankRevolutions: UInt16?
    private var previousCrankRevolutionsTime: UInt16?
    private var previousWheelRevolutions: UInt32?
    private var previousWheelRevolutionsTime: UInt16?
    private var averageCadence = AverageIntCalculator()
    private var averageSpeed = AverageDoubleCalculator()
    private var latestAverageCadenceUpdateTime = ContinuousClock.now
    private var latestAverageSpeedUpdateTime = ContinuousClock.now
    var wheelCircumferenceMeters = workoutDeviceDefaultWheelCircumferenceMeters

    func reset() {
        measurementCharacteristic = nil
        previousCrankRevolutions = nil
        previousCrankRevolutionsTime = nil
        previousWheelRevolutions = nil
        previousWheelRevolutionsTime = nil
    }

    func setMeasurementCharacteristic(_ characteristic: CBCharacteristic) {
        measurementCharacteristic = characteristic
    }

    func isAnyCharacteristicDiscovered() -> Bool {
        measurementCharacteristic != nil
    }

    func handleMeasurement(value: Data) throws -> (speedMetersPerSecond: Double, cadence: Int) {
        let measurement = try CscMeasurement(value: value)
        let now = ContinuousClock.now
        updateCadence(measurement: measurement, now: now)
        updateSpeed(measurement: measurement, now: now)
        return (averageSpeed.averageIgnoreZeros(), averageCadence.averageIgnoreZeros())
    }

    private func updateCadence(measurement: CscMeasurement, now: ContinuousClock.Instant) {
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
        if cadence != -1.0 {
            averageCadence.update(value: Int(cadence))
            latestAverageCadenceUpdateTime = now
        } else if latestAverageCadenceUpdateTime.duration(to: now) > .seconds(3) {
            averageCadence.update(value: 0)
        }
    }

    private func updateSpeed(measurement: CscMeasurement, now: ContinuousClock.Instant) {
        var speed = -1.0
        if let revolutions = measurement.cumulativeWheelRevolutions,
           let time = measurement.lastWheelEventTime
        {
            if let previousWheelRevolutions, let previousWheelRevolutionsTime {
                var deltaRevolutions = Int(revolutions) - Int(previousWheelRevolutions)
                if deltaRevolutions < 0 {
                    deltaRevolutions += 4_294_967_296
                }
                var deltaTime = Int(time) - Int(previousWheelRevolutionsTime)
                if deltaTime < 0 {
                    deltaTime += 65536
                }
                let deltaTimeSeconds = Double(deltaTime) / 1024
                if deltaTimeSeconds > 0 {
                    speed = Double(deltaRevolutions) * wheelCircumferenceMeters / deltaTimeSeconds
                    speed = min(speed, 100)
                }
            }
            previousWheelRevolutions = revolutions
            previousWheelRevolutionsTime = time
        }
        if speed != -1.0 {
            averageSpeed.update(value: speed)
            latestAverageSpeedUpdateTime = now
        } else if latestAverageSpeedUpdateTime.duration(to: now) > .seconds(3) {
            averageSpeed.update(value: 0)
        }
    }
}
