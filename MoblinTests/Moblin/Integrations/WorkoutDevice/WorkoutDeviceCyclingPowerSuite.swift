import Foundation
@testable import Moblin
import Testing

private func powerMeasurement(power: Int16) -> Data {
    var data = Data([0x00, 0x00])
    data.append(contentsOf: withUnsafeBytes(of: power.littleEndian) { Array($0) })
    return data
}

private func powerAndCrankMeasurement(power: Int16, revolutions: UInt16, eventTime: UInt16) -> Data {
    var data = Data([0x20, 0x00])
    data.append(contentsOf: withUnsafeBytes(of: power.littleEndian) { Array($0) })
    data.append(contentsOf: withUnsafeBytes(of: revolutions.littleEndian) { Array($0) })
    data.append(contentsOf: withUnsafeBytes(of: eventTime.littleEndian) { Array($0) })
    return data
}

struct WorkoutDeviceCyclingPowerSuite {
    @Test
    func powerOnlyDeviceReportsNoCadence() throws {
        let device = WorkoutDeviceCyclingPower()
        _ = try device.handleMeasurement(value: powerMeasurement(power: 150))
        let (power, cadence) = try device.handleMeasurement(value: powerMeasurement(power: 150))
        #expect(power == 100)
        #expect(cadence == nil)
    }

    @Test
    func calculatesCadenceFromCrankRevolutions() throws {
        let device = WorkoutDeviceCyclingPower()
        _ = try device.handleMeasurement(value: powerAndCrankMeasurement(power: 200,
                                                                         revolutions: 10,
                                                                         eventTime: 1024))
        let (_, cadence) = try device.handleMeasurement(value: powerAndCrankMeasurement(power: 200,
                                                                                        revolutions: 13,
                                                                                        eventTime: 1024 +
                                                                                            2048))
        #expect(cadence == 90)
    }

    @Test
    func resetForgetsCadence() throws {
        let device = WorkoutDeviceCyclingPower()
        _ = try device.handleMeasurement(value: powerAndCrankMeasurement(power: 200,
                                                                         revolutions: 10,
                                                                         eventTime: 1024))
        let (_, cadenceBeforeReset) = try device
            .handleMeasurement(value: powerAndCrankMeasurement(power: 200,
                                                               revolutions: 13,
                                                               eventTime: 1024 + 2048))
        #expect(cadenceBeforeReset == 90)
        device.reset()
        let (_, cadence) = try device.handleMeasurement(value: powerMeasurement(power: 200))
        #expect(cadence == nil)
    }
}
