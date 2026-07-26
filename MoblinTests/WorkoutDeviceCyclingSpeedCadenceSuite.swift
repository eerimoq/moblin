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
        let result = try device.handleMeasurement(value: crankOnlyMeasurement(revolutions: 100, eventTime: 0))
        #expect(result.cadence == 0)
        #expect(result.speedMetersPerSecond == 0)
    }

    @Test
    func crankCadenceIsSixtyRpmWhenOneRevolutionPerSecond() throws {
        let device = WorkoutDeviceCyclingSpeedCadence()
        _ = try device.handleMeasurement(value: crankOnlyMeasurement(revolutions: 100, eventTime: 0))
        let result = try device.handleMeasurement(value: crankOnlyMeasurement(revolutions: 101, eventTime: 1024))
        #expect(result.cadence == 60)
    }

    @Test
    func crankEventTimeRolloverIsHandled() throws {
        let device = WorkoutDeviceCyclingSpeedCadence()
        _ = try device.handleMeasurement(value: crankOnlyMeasurement(revolutions: 10, eventTime: 65500))
        let result = try device.handleMeasurement(value: crankOnlyMeasurement(revolutions: 11, eventTime: 100))
        #expect(result.cadence > 0)
    }

    @Test
    func wheelOnlyMeasurementDoesNotProduceCadence() throws {
        let device = WorkoutDeviceCyclingSpeedCadence()
        _ = try device.handleMeasurement(value: wheelOnlyMeasurement(revolutions: 1000, eventTime: 0))
        let result = try device.handleMeasurement(value: wheelOnlyMeasurement(revolutions: 1010, eventTime: 1024))
        #expect(result.cadence == 0)
    }

    @Test
    func wheelSpeedUsesDefaultCircumference() throws {
        let device = WorkoutDeviceCyclingSpeedCadence()
        _ = try device.handleMeasurement(value: wheelOnlyMeasurement(revolutions: 100, eventTime: 0))
        // 1 wheel rev in 1 second → circumference m/s
        let result = try device.handleMeasurement(value: wheelOnlyMeasurement(revolutions: 101, eventTime: 1024))
        #expect(abs(result.speedMetersPerSecond - workoutDeviceDefaultWheelCircumferenceMeters) < 0.001)
        #expect(result.cadence == 0)
    }

    @Test
    func serviceAndCharacteristicUuidsMatchBluetoothSpec() {
        #expect(workoutDeviceCyclingSpeedCadenceServiceId == CBUUID(string: "1816"))
        #expect(workoutDeviceCscMeasurementCharacteristicId == CBUUID(string: "2A5B"))
    }
}
