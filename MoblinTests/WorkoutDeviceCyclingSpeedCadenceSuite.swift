import CoreBluetooth
import Foundation
@testable import Moblin
import Testing

struct WorkoutDeviceCyclingSpeedCadenceSuite {
    private func crankOnlyMeasurement(revolutions: UInt16, eventTime: UInt16) -> Data {
        var data = Data([0x02])
        data.append(contentsOf: withUnsafeBytes(of: revolutions.littleEndian, Array.init))
        data.append(contentsOf: withUnsafeBytes(of: eventTime.littleEndian, Array.init))
        return data
    }

    private func wheelOnlyMeasurement(revolutions: UInt32, eventTime: UInt16) -> Data {
        var data = Data([0x01])
        data.append(contentsOf: withUnsafeBytes(of: revolutions.littleEndian, Array.init))
        data.append(contentsOf: withUnsafeBytes(of: eventTime.littleEndian, Array.init))
        return data
    }

    @Test
    func firstCrankMeasurementReturnsZeroCadence() throws {
        let device = WorkoutDeviceCyclingSpeedCadence()
        let cadence = try device.handleMeasurement(value: crankOnlyMeasurement(revolutions: 100, eventTime: 0))
        #expect(cadence == 0)
    }

    @Test
    func crankCadenceIsSixtyRpmWhenOneRevolutionPerSecond() throws {
        let device = WorkoutDeviceCyclingSpeedCadence()
        _ = try device.handleMeasurement(value: crankOnlyMeasurement(revolutions: 100, eventTime: 0))
        let cadence = try device.handleMeasurement(value: crankOnlyMeasurement(revolutions: 101, eventTime: 1024))
        #expect(cadence == 60)
    }

    @Test
    func crankEventTimeRolloverIsHandled() throws {
        let device = WorkoutDeviceCyclingSpeedCadence()
        _ = try device.handleMeasurement(value: crankOnlyMeasurement(revolutions: 10, eventTime: 65500))
        // 136 ticks later after rollover ≈ 0.1328 s for 1 rev → ~452 RPM, then averaged
        let cadence = try device.handleMeasurement(value: crankOnlyMeasurement(revolutions: 11, eventTime: 100))
        #expect(cadence > 0)
    }

    @Test
    func wheelOnlyMeasurementDoesNotProduceCadence() throws {
        let device = WorkoutDeviceCyclingSpeedCadence()
        _ = try device.handleMeasurement(value: wheelOnlyMeasurement(revolutions: 1000, eventTime: 0))
        let cadence = try device.handleMeasurement(value: wheelOnlyMeasurement(revolutions: 1010, eventTime: 1024))
        #expect(cadence == 0)
    }

    @Test
    func serviceAndCharacteristicUuidsMatchBluetoothSpec() {
        #expect(workoutDeviceCyclingSpeedCadenceServiceId == CBUUID(string: "1816"))
        #expect(workoutDeviceCscMeasurementCharacteristicId == CBUUID(string: "2A5B"))
    }
}
