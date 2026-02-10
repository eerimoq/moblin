import CoreBluetooth

let workoutDeviceRunningServiceId = CBUUID(string: "1814")
let workoutDeviceRunningMeasurementCharacteristicId = CBUUID(string: "2A53")

private let rscStrideLengthFlagIndex = 0
private let rscTotalDistanceFlagIndex = 1

struct WorkoutDeviceRunningMetrics: Codable {
    var speed: Double?
    var cadence: Int?
    var distance: Double?
}

private struct RscMeasurement {
    var speedMetersPerSecond: Double
    var cadence: Int
    var totalDistanceMeters: Double?

    init(value: Data) throws {
        let reader = ByteReader(data: value)
        let flags = try reader.readUInt8()
        let speedRaw = try reader.readUInt16Le()
        speedMetersPerSecond = Double(speedRaw) / 256.0
        cadence = try Int(reader.readUInt8())
        if flags.isBitSet(index: rscStrideLengthFlagIndex) {
            _ = try reader.readUInt16Le()
        }
        if flags.isBitSet(index: rscTotalDistanceFlagIndex) {
            let totalDistanceRaw = try reader.readUInt32Le()
            totalDistanceMeters = Double(totalDistanceRaw) / 10.0
        }
    }
}

class WorkoutDeviceRunning {
    private var measurementCharacteristic: CBCharacteristic?
    private var lastRscUpdateTime: ContinuousClock.Instant?
    private var distanceMetersFallback = 0.0
    private var usingDeviceDistance = false
    
    func reset() {
        measurementCharacteristic = nil
        lastRscUpdateTime = nil
        distanceMetersFallback = 0
        usingDeviceDistance = false
    }
    
    func setMeasurementCharacteristic(_ characteristic: CBCharacteristic) {
        measurementCharacteristic = characteristic
    }
    
    func isAnyCharacteristicDiscovered() -> Bool {
        return measurementCharacteristic != nil
    }
    
    func handleMeasurement(value: Data) throws -> WorkoutDeviceRunningMetrics {
        let measurement = try RscMeasurement(value: value)
        var distanceMeters: Double?
        if let totalDistanceMeters = measurement.totalDistanceMeters {
            usingDeviceDistance = true
            distanceMeters = totalDistanceMeters
        } else if !usingDeviceDistance {
            let now = ContinuousClock.now
            if let lastRscUpdateTime {
                let deltaSeconds = lastRscUpdateTime.duration(to: now).seconds
                if deltaSeconds > 0 {
                    distanceMetersFallback += measurement.speedMetersPerSecond * deltaSeconds
                }
            }
            distanceMeters = distanceMetersFallback
            lastRscUpdateTime = now
        }
        return WorkoutDeviceRunningMetrics(speed: measurement.speedMetersPerSecond,
                                           cadence: measurement.cadence,
                                           distance: distanceMeters)
    }
}
