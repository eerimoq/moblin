import CoreBluetooth
import Foundation

let heartRateServiceId = CBUUID(string: "180D")
let heartRateMeasurementCharacteristicId = CBUUID(string: "2A37")

private let measurementHeartRateValueFormatIndex = 0

struct HeartRateMeasurement {
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
