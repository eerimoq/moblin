import Foundation
@testable import Moblin
import Testing

private func crankMeasurement(revolutions: UInt16, eventTime: UInt16) -> Data {
    var data = Data([0x02])
    data.append(contentsOf: withUnsafeBytes(of: revolutions.littleEndian) { Array($0) })
    data.append(contentsOf: withUnsafeBytes(of: eventTime.littleEndian) { Array($0) })
    return data
}

private func wheelMeasurement(revolutions: UInt32, eventTime: UInt16) -> Data {
    var data = Data([0x01])
    data.append(contentsOf: withUnsafeBytes(of: revolutions.littleEndian) { Array($0) })
    data.append(contentsOf: withUnsafeBytes(of: eventTime.littleEndian) { Array($0) })
    return data
}

private func wheelAndCrankMeasurement(wheelRevolutions: UInt32,
                                      wheelEventTime: UInt16,
                                      crankRevolutions: UInt16,
                                      crankEventTime: UInt16) -> Data
{
    var data = Data([0x03])
    data.append(contentsOf: withUnsafeBytes(of: wheelRevolutions.littleEndian) { Array($0) })
    data.append(contentsOf: withUnsafeBytes(of: wheelEventTime.littleEndian) { Array($0) })
    data.append(contentsOf: withUnsafeBytes(of: crankRevolutions.littleEndian) { Array($0) })
    data.append(contentsOf: withUnsafeBytes(of: crankEventTime.littleEndian) { Array($0) })
    return data
}

struct WorkoutDeviceCyclingSpeedCadenceSuite {
    @Test
    func firstMeasurementOnlySeedsState() throws {
        let device = WorkoutDeviceCyclingSpeedCadence()
        let metrics = try device.handleMeasurement(value: crankMeasurement(revolutions: 10,
                                                                           eventTime: 1024))
        #expect(metrics.cadence == 0)
        #expect(metrics.speed == nil)
    }

    @Test
    func calculatesCadenceFromCrankRevolutions() throws {
        let device = WorkoutDeviceCyclingSpeedCadence()
        _ = try device.handleMeasurement(value: crankMeasurement(revolutions: 10, eventTime: 1024))
        let metrics = try device.handleMeasurement(value: crankMeasurement(revolutions: 13,
                                                                           eventTime: 1024 + 2048))
        #expect(metrics.cadence == 90)
    }

    @Test
    func handlesCrankRevolutionsWrapAround() throws {
        let device = WorkoutDeviceCyclingSpeedCadence()
        _ = try device.handleMeasurement(value: crankMeasurement(revolutions: 65535, eventTime: 65000))
        let metrics = try device.handleMeasurement(value: crankMeasurement(revolutions: 0,
                                                                           eventTime: 65000 &+ 1024))
        #expect(metrics.cadence == 60)
    }

    @Test
    func ignoresMeasurementWithoutTimeProgress() throws {
        let device = WorkoutDeviceCyclingSpeedCadence()
        _ = try device.handleMeasurement(value: crankMeasurement(revolutions: 10, eventTime: 1024))
        _ = try device.handleMeasurement(value: crankMeasurement(revolutions: 11, eventTime: 1024 + 1024))
        let metrics = try device.handleMeasurement(value: crankMeasurement(revolutions: 11,
                                                                           eventTime: 1024 + 1024))
        #expect(metrics.cadence == 60)
    }

    @Test
    func cadenceOnlySensorReportsNoSpeed() throws {
        let device = WorkoutDeviceCyclingSpeedCadence()
        _ = try device.handleMeasurement(value: crankMeasurement(revolutions: 10, eventTime: 1024))
        let metrics = try device.handleMeasurement(value: crankMeasurement(revolutions: 11,
                                                                           eventTime: 1024 + 1024))
        #expect(metrics.cadence == 60)
        #expect(metrics.speed == nil)
        #expect(device.isReportingCrankRevolutions())
    }

    @Test
    func speedOnlySensorReportsNoCadence() throws {
        let device = WorkoutDeviceCyclingSpeedCadence()
        device.setWheelCircumference(millimeters: 2000)
        _ = try device.handleMeasurement(value: wheelMeasurement(revolutions: 100, eventTime: 1024))
        let metrics = try device.handleMeasurement(value: wheelMeasurement(revolutions: 105,
                                                                           eventTime: 1024 + 1024))
        #expect(metrics.cadence == nil)
        #expect(try isEqual(#require(metrics.speed), 10, epsilon: 0.001))
        #expect(!device.isReportingCrankRevolutions())
    }

    @Test
    func calculatesSpeedAndCadenceFromCombinedMeasurement() throws {
        let device = WorkoutDeviceCyclingSpeedCadence()
        device.setWheelCircumference(millimeters: 2000)
        _ = try device.handleMeasurement(value: wheelAndCrankMeasurement(wheelRevolutions: 100,
                                                                         wheelEventTime: 1024,
                                                                         crankRevolutions: 10,
                                                                         crankEventTime: 1024))
        let metrics = try device.handleMeasurement(value: wheelAndCrankMeasurement(
            wheelRevolutions: 105,
            wheelEventTime: 1024 + 1024,
            crankRevolutions: 11,
            crankEventTime: 1024 + 1024
        ))
        #expect(metrics.cadence == 60)
        #expect(try isEqual(#require(metrics.speed), 10, epsilon: 0.001))
    }

    @Test
    func handlesWheelRevolutionsWrapAround() throws {
        let device = WorkoutDeviceCyclingSpeedCadence()
        device.setWheelCircumference(millimeters: 2000)
        _ = try device.handleMeasurement(value: wheelMeasurement(revolutions: .max, eventTime: 1024))
        let metrics = try device.handleMeasurement(value: wheelMeasurement(revolutions: 4,
                                                                           eventTime: 1024 + 1024))
        #expect(try isEqual(#require(metrics.speed), 10, epsilon: 0.001))
    }

    @Test
    func rejectsTruncatedMeasurement() {
        let device = WorkoutDeviceCyclingSpeedCadence()
        #expect(throws: (any Error).self) {
            try device.handleMeasurement(value: Data([0x02, 0x01]))
        }
    }
}
