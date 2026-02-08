import CoreBluetooth

let workoutDeviceHeartRateServiceId = CBUUID(string: "180D")
let workoutDeviceHeartRateMeasurementCharacteristicId = CBUUID(string: "2A37")
private let measurementHeartRateValueFormatIndex = 0

private struct HeartRateMeasurement {
    var heartRate: UInt16 = 0

    init(value: Data) throws {
        let reader = ByteReader(data: value)
        let flags = try reader.readUInt8()
        if flags.isBitSet(index: measurementHeartRateValueFormatIndex) {
            heartRate = try reader.readUInt16Le()
        } else {
            heartRate = try UInt16(reader.readUInt8())
        }
    }
}

class WorkoutDeviceHeartRate {
    private var measurementCharacteristic: CBCharacteristic?

    func reset() {
        measurementCharacteristic = nil
    }

    func setMeasurementCharacteristic(_ characteristic: CBCharacteristic) {
        measurementCharacteristic = characteristic
    }

    func isAnyCharacteristicDiscovered() -> Bool {
        return measurementCharacteristic != nil
    }

    func handleMeasurement(value: Data) throws -> Int {
        let measurement = try HeartRateMeasurement(value: value)
        return Int(measurement.heartRate)
    }
}
