import CoreBluetooth
import Foundation

nonisolated(unsafe) let workoutDeviceCyclingSpeedCadenceServiceId = CBUUID(string: "1816")
nonisolated(unsafe) let workoutDeviceCyclingSpeedCadenceMeasurementCharacteristicId = CBUUID(string: "2A5B")

private let measurementWheelRevolutionDataFlagIndex = 0
private let measurementCrankRevolutionDataFlagIndex = 1
private let maximumCyclingSpeedMetersPerSecond = 100.0

struct WorkoutDeviceCyclingSpeedSample {
    let speed: Double
    let time: ContinuousClock.Instant

    func value(now: ContinuousClock.Instant = .now) -> Double {
        time.duration(to: now) < .seconds(3) ? speed : 0
    }
}

struct WorkoutDeviceCyclingMetrics: Codable, Equatable {
    var speed: Double?
    var distance: Double?
}

struct WorkoutDeviceCyclingMetricsStore {
    private var metrics: [UUID: WorkoutDeviceCyclingMetrics] = [:]
    private var speedSamples: [UUID: WorkoutDeviceCyclingSpeedSample] = [:]

    func genericMetrics(deviceIds: [UUID], now: ContinuousClock.Instant) -> WorkoutDeviceCyclingMetrics {
        guard let id = deviceIds.first(where: { metrics[$0] != nil }), var value = metrics[id] else {
            return .init(speed: 0, distance: 0)
        }
        value.speed = speedSamples[id]?.value(now: now) ?? 0
        return value
    }

    mutating func update(deviceId: UUID, speed: Double?, distance: Double?,
                         now: ContinuousClock.Instant = .now)
    {
        guard speed != nil || distance != nil else {
            return
        }
        var value = metrics[deviceId] ?? .init()
        if let speed {
            speedSamples[deviceId] = WorkoutDeviceCyclingSpeedSample(speed: speed, time: now)
        }
        if let distance {
            value.distance = distance
        }
        metrics[deviceId] = value
    }

    mutating func disconnect(deviceId: UUID) {
        speedSamples.removeValue(forKey: deviceId)
    }

    mutating func remove(deviceId: UUID) {
        disconnect(deviceId: deviceId)
        metrics.removeValue(forKey: deviceId)
    }

    func metricsByName(devices: [(id: UUID, name: String)], now: ContinuousClock.Instant)
        -> [String: WorkoutDeviceCyclingMetrics]
    {
        var result: [String: WorkoutDeviceCyclingMetrics] = [:]
        let devicesByName = Dictionary(grouping: devices, by: { $0.name.lowercased() })
        for (name, devices) in devicesByName {
            guard devices.count == 1, let device = devices.first, var value = metrics[device.id] else {
                continue
            }
            value.speed = speedSamples[device.id]?.value(now: now)
            result[name] = value
        }
        return result
    }
}

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

private struct CyclingWheelSample {
    let revolutions: UInt32
    let eventTime: UInt16
    let receivedAt: ContinuousClock.Instant

    func elapsedSeconds(since previous: Self) -> Double {
        let elapsed = previous.receivedAt.duration(to: receivedAt).components
        return Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
    }

    func eventSeconds(since previous: Self) -> Double {
        Double(eventTime &- previous.eventTime) / 1024
    }

    func distance(since previous: Self, wheelCircumference: Double) -> Double {
        Double(revolutions &- previous.revolutions) * wheelCircumference
    }
}

private enum CyclingSpeedMeasurement {
    case noMeasurement
    case speed(Double)
}

class WorkoutDeviceCyclingSpeedCadence {
    private var measurementCharacteristic: CBCharacteristic?
    private var previousWheelSample: CyclingWheelSample?
    private var pendingWheelReset: CyclingWheelSample?
    private var needsSpeedBaseline = true
    private let crankCadence = WorkoutDeviceCrankCadence()
    private let averageSpeed = WorkoutDeviceAverageCalculator()
    private var latestAverageSpeedUpdateTime = ContinuousClock.now
    private var reportsWheelRevolutions = false
    private var wheelCircumferenceMeters: Double
    private(set) var distanceMeters = 0.0

    init(wheelCircumference: Int) {
        wheelCircumferenceMeters = Double(wheelCircumference) / 1000
    }

    func reset(preserveDistance: Bool = false) {
        measurementCharacteristic = nil
        resetMeasurements()
        reportsWheelRevolutions = false
        if !preserveDistance {
            distanceMeters = 0
            previousWheelSample = nil
        }
    }

    func resetMeasurements() {
        needsSpeedBaseline = true
        pendingWheelReset = nil
        crankCadence.reset()
        averageSpeed.reset()
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

    func handleMeasurement(value: Data, now: ContinuousClock.Instant = .now) throws
        -> (speed: Double?, cadence: Int?, distance: Double?)
    {
        let measurement = try CyclingSpeedCadenceMeasurement(value: value)
        let cadence = crankCadence.update(revolutions: measurement.cumulativeCrankRevolutions,
                                          time: measurement.lastCrankEventTime,
                                          now: now)
        updateSpeed(measurement: measurement, now: now)
        return (reportsWheelRevolutions ? averageSpeed.averageIgnoreZeros() : nil,
                cadence,
                reportsWheelRevolutions ? distanceMeters : nil)
    }

    private func updateSpeed(measurement: CyclingSpeedCadenceMeasurement, now: ContinuousClock.Instant) {
        var result = CyclingSpeedMeasurement.noMeasurement
        if let revolutions = measurement.cumulativeWheelRevolutions,
           let time = measurement.lastWheelEventTime
        {
            reportsWheelRevolutions = true
            result = updateWheelSample(CyclingWheelSample(revolutions: revolutions,
                                                          eventTime: time,
                                                          receivedAt: now))
        }
        switch result {
        case let .speed(speed):
            averageSpeed.update(value: speed)
            latestAverageSpeedUpdateTime = now
        case .noMeasurement:
            if latestAverageSpeedUpdateTime.duration(to: now) > .seconds(3) {
                averageSpeed.update(value: 0)
            }
        }
    }

    private func isPlausibleDistance(from previous: CyclingWheelSample,
                                     to current: CyclingWheelSample) -> Bool
    {
        current.distance(since: previous, wheelCircumference: wheelCircumferenceMeters)
            <= maximumCyclingSpeedMetersPerSecond * max(1, current.elapsedSeconds(since: previous) + 1)
    }

    private func updateWheelSample(_ current: CyclingWheelSample) -> CyclingSpeedMeasurement {
        var baseline = previousWheelSample
        var resetConfirmed = false
        if let previousWheelSample, !isPlausibleDistance(from: previousWheelSample, to: current) {
            if let pendingWheelReset,
               current.revolutions != pendingWheelReset.revolutions,
               current.eventSeconds(since: pendingWheelReset) > 0,
               isPlausibleDistance(from: pendingWheelReset, to: current)
            {
                if !needsSpeedBaseline,
                   current.elapsedSeconds(since: previousWheelSample) < 64,
                   current.eventSeconds(since: previousWheelSample) >= 32
                {
                    averageSpeed.reset()
                    return .speed(0)
                }
                baseline = pendingWheelReset
                resetConfirmed = true
            } else {
                if pendingWheelReset?.revolutions != current.revolutions
                    || pendingWheelReset?.eventTime != current.eventTime
                {
                    pendingWheelReset = current
                }
                averageSpeed.reset()
                return .speed(0)
            }
        }
        let speedBaselineMissing = needsSpeedBaseline
        previousWheelSample = current
        pendingWheelReset = nil
        needsSpeedBaseline = false
        guard let baseline else {
            return .noMeasurement
        }
        let distance = current.distance(since: baseline, wheelCircumference: wheelCircumferenceMeters)
        distanceMeters += distance
        let elapsedSeconds = current.elapsedSeconds(since: baseline)
        if (!resetConfirmed && speedBaselineMissing) || elapsedSeconds >= 64
            || (resetConfirmed && elapsedSeconds >= 3)
        {
            averageSpeed.reset()
            return .speed(0)
        }
        let eventSeconds = current.eventSeconds(since: baseline)
        guard eventSeconds > 0 else {
            return .noMeasurement
        }
        let speed = distance / eventSeconds
        guard speed <= maximumCyclingSpeedMetersPerSecond else {
            averageSpeed.reset()
            return .speed(0)
        }
        return .speed(speed)
    }
}
