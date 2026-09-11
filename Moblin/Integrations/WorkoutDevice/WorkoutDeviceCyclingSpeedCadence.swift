@preconcurrency import CoreBluetooth
import Foundation

let workoutDeviceCyclingSpeedCadenceServiceId = CBUUID(string: "1816")
let workoutDeviceCyclingSpeedCadenceMeasurementCharacteristicId = CBUUID(string: "2A5B")

private let measurementWheelRevolutionDataFlagIndex = 0
private let measurementCrankRevolutionDataFlagIndex = 1

private struct CyclingSpeedCadenceMeasurement {
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

class WorkoutDeviceCyclingSpeedCadence {
    private var measurementCharacteristic: CBCharacteristic?
    private var previousWheelRevolutions: UInt32?
    private var previousWheelRevolutionsTime: UInt16?
    private let crankCadence = WorkoutDeviceCrankCadence()
    private let averageSpeed = WorkoutDeviceAverageCalculator()
    private var latestAverageSpeedUpdateTime = ContinuousClock.now
    private var reportsCadence = false
    private var reportsWheelRevolutions = false
    private var wheelCircumferenceMeters: Double

    init(wheelCircumference: Int) {
        wheelCircumferenceMeters = Double(wheelCircumference) / 1000
    }

    func reset() {
        measurementCharacteristic = nil
        previousWheelRevolutions = nil
        previousWheelRevolutionsTime = nil
        crankCadence.reset()
        averageSpeed.reset()
        reportsCadence = false
        reportsWheelRevolutions = false
    }

    func setMeasurementCharacteristic(_ characteristic: CBCharacteristic) {
        measurementCharacteristic = characteristic
    }

    func isAnyCharacteristicDiscovered() -> Bool {
        measurementCharacteristic != nil
    }

    func setWheelCircumference(millimeters: Int) {
        wheelCircumferenceMeters = Double(millimeters) / 1000
    }

    func isReportingCadence() -> Bool {
        reportsCadence
    }

    func handleMeasurement(value: Data) throws -> (Double?, Int?) {
        let measurement = try CyclingSpeedCadenceMeasurement(value: value)
        let now = ContinuousClock.now
        if measurement.cumulativeCrankRevolutions != nil {
            reportsCadence = true
        }
        let cadence = crankCadence.update(revolutions: measurement.cumulativeCrankRevolutions,
                                          time: measurement.lastCrankEventTime,
                                          now: now)
        updateSpeed(measurement: measurement, now: now)
        return (reportsWheelRevolutions ? averageSpeed.averageIgnoreZeros() : nil,
                reportsCadence ? cadence : nil)
    }

    private func updateSpeed(measurement: CyclingSpeedCadenceMeasurement, now: ContinuousClock.Instant) {
        var speed = -1.0
        if let revolutions = measurement.cumulativeWheelRevolutions,
           let time = measurement.lastWheelEventTime
        {
            reportsWheelRevolutions = true
            if let previousWheelRevolutions, let previousWheelRevolutionsTime {
                var deltaRevolutions = Int(revolutions) - Int(previousWheelRevolutions)
                if deltaRevolutions < 0 {
                    deltaRevolutions += 4_294_967_296
                }
                deltaRevolutions = min(deltaRevolutions, 1000)
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
