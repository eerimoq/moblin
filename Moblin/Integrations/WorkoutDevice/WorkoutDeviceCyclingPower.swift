import Collections
@preconcurrency import CoreBluetooth
import Foundation

let workoutDeviceCyclingPowerServiceId = CBUUID(string: "1818")
let workoutDeviceCyclingPowerMeasurementCharacteristicId = CBUUID(string: "2A63")
let workoutDeviceCyclingPowerVectorCharacteristicId = CBUUID(string: "2A64")

private let measurementPedalPowerBalanceFlagIndex = 0
private let measurementAccumulatedTorqueFlagIndex = 2
private let measurementWheelRevolutionDataFlagIndex = 4
private let measurementCrankRevolutionDataFlagIndex = 5
private let measurementExtremeForceFlagIndex = 6
private let measurementExtremeTorqueFlagIndex = 7
private let measurementExtremeAnglesFlagIndex = 8
private let measurementTopDeadSpotAngleFlagIndex = 9
private let measurementBottomDeadSpotAngleFlagIndex = 10
private let measurementAccumulatedEnergyFlagIndex = 11

private struct PowerMeasurement {
    var instantaneousPower: UInt16 = 0
    // periphery:ignore
    var pedalPowerBalance: UInt8?
    // periphery:ignore
    var accumulatedTorque: UInt16?
    // periphery:ignore
    var cumulativeWheelRevolutions: UInt32?
    // periphery:ignore
    var lastWheelEventTime: UInt16?
    var cumulativeCrankRevolutions: UInt16?
    var lastCrankEventTime: UInt16?
    // periphery:ignore
    var maximumForceMagnitude: UInt16?
    // periphery:ignore
    var minimumForceMagnitude: UInt16?
    // periphery:ignore
    var maximumTorqueMagnitude: UInt16?
    // periphery:ignore
    var minimumTorqueMagnitude: UInt16?
    // periphery:ignore
    var extremeAngles: UInt16?
    // periphery:ignore
    var topDeadSpotAngle: UInt16?
    // periphery:ignore
    var bottomDeadSpotAngle: UInt16?
    // periphery:ignore
    var accumulatedEnergy: UInt16?

    init(value: Data) throws {
        let reader = ByteReader(data: value)
        let flags = try reader.readUInt16Le()
        instantaneousPower = try reader.readUInt16Le()
        if flags.isBitSet(index: measurementPedalPowerBalanceFlagIndex) {
            pedalPowerBalance = try reader.readUInt8()
        }
        if flags.isBitSet(index: measurementAccumulatedTorqueFlagIndex) {
            accumulatedTorque = try reader.readUInt16Le()
        }
        if flags.isBitSet(index: measurementWheelRevolutionDataFlagIndex) {
            cumulativeWheelRevolutions = try reader.readUInt32Le()
            lastWheelEventTime = try reader.readUInt16Le()
        }
        if flags.isBitSet(index: measurementCrankRevolutionDataFlagIndex) {
            cumulativeCrankRevolutions = try reader.readUInt16Le()
            lastCrankEventTime = try reader.readUInt16Le()
        }
        if flags.isBitSet(index: measurementExtremeForceFlagIndex) {
            maximumForceMagnitude = try reader.readUInt16Le()
            minimumForceMagnitude = try reader.readUInt16Le()
        }
        if flags.isBitSet(index: measurementExtremeTorqueFlagIndex) {
            maximumTorqueMagnitude = try reader.readUInt16Le()
            minimumTorqueMagnitude = try reader.readUInt16Le()
        }
        if flags.isBitSet(index: measurementExtremeAnglesFlagIndex) {
            _ = try reader.readBytes(3)
        }
        if flags.isBitSet(index: measurementTopDeadSpotAngleFlagIndex) {
            topDeadSpotAngle = try reader.readUInt16Le()
        }
        if flags.isBitSet(index: measurementBottomDeadSpotAngleFlagIndex) {
            bottomDeadSpotAngle = try reader.readUInt16Le()
        }
        if flags.isBitSet(index: measurementAccumulatedEnergyFlagIndex) {
            accumulatedEnergy = try reader.readUInt16Le()
        }
    }
}

private let vectorCrankRevolutionDataFlagIndex = 0
private let vectorFirstCrankMeasurementAngleFlagIndex = 1
private let vectorInstantaneousForceArrayFlagIndex = 2
private let vectorInstantaneousTorqueArrayFlagIndex = 3
private let vectorInstantaneousMeasurementDirectionMask: UInt8 = 0b110000
private let vectorInstantaneousMeasurementDirectionIndex = 4

private enum WorkoutDeviceCyclingPowerInstantaneousMeasurementDirection: UInt8 {
    case unknown = 0
    case tangentialComponent = 1
    case radialComponent = 2
    case lateralComponent = 3
}

private struct PowerVector {
    // periphery:ignore
    var cumulativeCrankRevolutions: UInt16?
    // periphery:ignore
    var lastCrankEventTime: UInt16?
    // periphery:ignore
    var firstCrankMeasurementAngle: UInt16?
    var instantaneousForceMagnitudes: [UInt16]?
    var instantaneousTorqueMagnitudes: [UInt16]?
    // periphery:ignore
    var instantaneousMeasurementDirection: WorkoutDeviceCyclingPowerInstantaneousMeasurementDirection?

    init(value: Data) throws {
        let reader = ByteReader(data: value)
        let flags = try reader.readUInt8()
        if flags.isBitSet(index: vectorCrankRevolutionDataFlagIndex) {
            cumulativeCrankRevolutions = try reader.readUInt16Le()
            lastCrankEventTime = try reader.readUInt16Le()
        }
        if flags.isBitSet(index: vectorFirstCrankMeasurementAngleFlagIndex) {
            firstCrankMeasurementAngle = try reader.readUInt16Le()
        }
        while reader.bytesAvailable >= 2 {
            let value = try reader.readUInt16Le()
            if flags.isBitSet(index: vectorInstantaneousForceArrayFlagIndex) {
                if instantaneousForceMagnitudes == nil {
                    instantaneousForceMagnitudes = []
                }
                instantaneousForceMagnitudes!.append(value)
            } else if flags.isBitSet(index: vectorInstantaneousTorqueArrayFlagIndex) {
                if instantaneousTorqueMagnitudes == nil {
                    instantaneousTorqueMagnitudes = []
                }
                instantaneousTorqueMagnitudes!.append(value)
            }
        }
        let value = (flags & vectorInstantaneousMeasurementDirectionMask) >>
            vectorInstantaneousMeasurementDirectionIndex
        instantaneousMeasurementDirection =
            WorkoutDeviceCyclingPowerInstantaneousMeasurementDirection(rawValue: value)
    }
}

class WorkoutDeviceCyclingPower {
    private var measurementCharacteristic: CBCharacteristic?
    private let averagePower = WorkoutDeviceAverageCalculator()
    private let crankCadence = WorkoutDeviceCrankCadence()
    private var reportsCadence = false

    func reset() {
        measurementCharacteristic = nil
        crankCadence.reset()
        reportsCadence = false
    }

    func setMeasurementCharacteristic(_ characteristic: CBCharacteristic) {
        measurementCharacteristic = characteristic
    }

    func isAnyCharacteristicDiscovered() -> Bool {
        measurementCharacteristic != nil
    }

    func handleMeasurement(value: Data) throws -> (Int, Int?) {
        let measurement = try PowerMeasurement(value: value)
        averagePower.update(value: Double(measurement.instantaneousPower))
        if measurement.cumulativeCrankRevolutions != nil {
            reportsCadence = true
        }
        let cadence = crankCadence.update(revolutions: measurement.cumulativeCrankRevolutions,
                                          time: measurement.lastCrankEventTime,
                                          now: .now)
        return (Int(averagePower.average()), reportsCadence ? cadence : nil)
    }

    func handlePowerVector(value: Data) throws {
        _ = try PowerVector(value: value)
    }
}
