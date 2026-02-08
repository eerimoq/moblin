import CoreBluetooth
import Foundation

// Cycling Power Protocol
let cyclingPowerServiceId = CBUUID(string: "1818")
let cyclingPowerMeasurementCharacteristicId = CBUUID(string: "2A63")
let vectorCharacteristicId = CBUUID(string: "2A64")

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

struct CyclingPowerMeasurement {
    var instantaneousPower: UInt16 = 0
    var pedalPowerBalance: UInt8?
    var accumulatedTorque: UInt16?
    var cumulativeWheelRevolutions: UInt32?
    var lastWheelEventTime: UInt16?
    var cumulativeCrankRevolutions: UInt16?
    var lastCrankEventTime: UInt16?
    var maximumForceMagnitude: UInt16?
    var minimumForceMagnitude: UInt16?
    var maximumTorqueMagnitude: UInt16?
    var minimumTorqueMagnitude: UInt16?
    var extremeAngles: UInt16?
    var topDeadSpotAngle: UInt16?
    var bottomDeadSpotAngle: UInt16?
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

enum CyclingPowerInstantaneousMeasurementDirection: UInt8 {
    case unknown = 0
    case tangentialComponent = 1
    case radialComponent = 2
    case lateralComponent = 3
}

struct CyclingPowerVector {
    var cumulativeCrankRevolutions: UInt16?
    var lastCrankEventTime: UInt16?
    var firstCrankMeasurementAngle: UInt16?
    var instantaneousForceMagnitudes: [UInt16]?
    var instantaneousTorqueMagnitudes: [UInt16]?
    var instantaneousMeasurementDirection: CyclingPowerInstantaneousMeasurementDirection?

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
        instantaneousMeasurementDirection = CyclingPowerInstantaneousMeasurementDirection(rawValue: value)
    }
}

let averageSampleCount = 3

class AverageMeasurementCalculator {
    private var values = Array(repeating: 0, count: averageSampleCount)
    private var nextIndex = 0

    func update(value: Int) {
        values[nextIndex] = value
        nextIndex += 1
        nextIndex %= averageSampleCount
    }

    func average() -> Int {
        return values.reduce(0, +) / averageSampleCount
    }

    func averageIgnoreZeros() -> Int {
        let numberOfNonZeroValues = values.filter { $0 != 0 }.count
        guard numberOfNonZeroValues > 0 else {
            return 0
        }
        return values.reduce(0, +) / numberOfNonZeroValues
    }
}

class CyclingPowerState {
    private var previousRevolutions: UInt16?
    private var previousRevolutionsTime: UInt16?
    private var averagePower = AverageMeasurementCalculator()
    private var averageCadence = AverageMeasurementCalculator()
    private var latestAverageCadenceUpdateTime = ContinuousClock.now
    
    func reset() {
        previousRevolutions = nil
        previousRevolutionsTime = nil
        averagePower = AverageMeasurementCalculator()
        averageCadence = AverageMeasurementCalculator()
        latestAverageCadenceUpdateTime = ContinuousClock.now
    }
    
    func processMeasurement(_ measurement: CyclingPowerMeasurement) -> (power: Int, cadence: Int) {
        var cadence = -1.0
        if let revolutions = measurement.cumulativeCrankRevolutions,
           let time = measurement.lastCrankEventTime
        {
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
        averagePower.update(value: Int(measurement.instantaneousPower))
        let now = ContinuousClock.now
        if cadence != -1.0 {
            averageCadence.update(value: Int(cadence))
            latestAverageCadenceUpdateTime = now
        } else if latestAverageCadenceUpdateTime.duration(to: now) > .seconds(3) {
            averageCadence.update(value: 0)
        }
        return (power: averagePower.average(), cadence: averageCadence.averageIgnoreZeros())
    }
}
