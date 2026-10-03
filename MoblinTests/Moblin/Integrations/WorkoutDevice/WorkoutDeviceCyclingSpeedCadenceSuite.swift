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
    private let device = WorkoutDeviceCyclingSpeedCadence(wheelCircumference: 2000)
    private let now = ContinuousClock.now

    @discardableResult
    private func wheel(_ revolutions: UInt32, eventTime: UInt16, after delay: Duration = .zero) throws
        -> (speed: Double?, cadence: Int?, distance: Double?)
    {
        try device.handleMeasurement(value: wheelMeasurement(revolutions: revolutions, eventTime: eventTime),
                                     now: now.advanced(by: delay))
    }

    @Test(arguments: [1, 1000])
    func idleSpeedAndCadenceExpireAfterThreeZeroSamples(packetIntervalMilliseconds: Int) throws {
        for index in 0 ... 3 {
            _ = try device.handleMeasurement(
                value: wheelAndCrankMeasurement(wheelRevolutions: UInt32(index),
                                                wheelEventTime: UInt16(index * 1024),
                                                crankRevolutions: UInt16(index),
                                                crankEventTime: UInt16(index * 1024)),
                now: now.advanced(by: .seconds(index))
            )
        }
        let stopped = wheelAndCrankMeasurement(wheelRevolutions: 3, wheelEventTime: 3072,
                                               crankRevolutions: 3, crankEventTime: 3072)
        let boundary = try device.handleMeasurement(value: stopped, now: now.advanced(by: .seconds(6)))
        #expect(boundary.speed == 2)
        #expect(boundary.cadence == 60)
        for index in 1 ... 3 {
            let result = try device.handleMeasurement(
                value: stopped,
                now: now.advanced(by: .milliseconds(6000 + index * packetIntervalMilliseconds))
            )
            #expect(result.speed == (index < 3 ? 2 : 0))
            #expect(result.cadence == (index < 3 ? 60 : 0))
            #expect(result.distance == 6)
        }
        let resumed = try device.handleMeasurement(
            value: wheelAndCrankMeasurement(wheelRevolutions: 4, wheelEventTime: 4096,
                                            crankRevolutions: 4, crankEventTime: 4096),
            now: now.advanced(by: .milliseconds(7000 + 3 * packetIntervalMilliseconds))
        )
        #expect(resumed.speed == 2)
        #expect(resumed.cadence == 60)
        #expect(resumed.distance == 8)
    }

    @Test(arguments: [99, 100, 101])
    func speedLimitKeepsPlausibleDistanceAndRecovers(revolutionsPerSecond: Int) throws {
        device.setWheelCircumference(millimeters: 1000)
        try wheel(0, eventTime: 0)
        try wheel(1, eventTime: 1024, after: .seconds(1))
        let revolutions = UInt32(1 + revolutionsPerSecond)
        let result = try wheel(revolutions, eventTime: 2048, after: .seconds(2))
        let acceptedSpeed = revolutionsPerSecond <= 100
        #expect(result.speed == (acceptedSpeed ? Double(1 + revolutionsPerSecond) / 2 : 0))
        #expect(result.distance == Double(revolutions))
        let recovered = try wheel(revolutions + 2, eventTime: 3072, after: .seconds(3))
        #expect(recovered.speed == (acceptedSpeed ? Double(3 + revolutionsPerSecond) / 3 : 2))
        #expect(recovered.distance == Double(revolutions + 2))
    }

    @Test(arguments: [UInt32(0), 100_000])
    func invalidCounterClearsSpeedWithoutAddingDistanceAndRecovers(rejectedRevolutions: UInt32) throws {
        try wheel(100, eventTime: 0)
        let moving = try wheel(101, eventTime: 1024, after: .seconds(1))
        #expect(moving.speed == 2)
        let rejected = try wheel(rejectedRevolutions, eventTime: 2048, after: .seconds(2))
        #expect(rejected.speed == 0)
        #expect(rejected.distance == 2)
        let recovered = try wheel(102, eventTime: 2048, after: .seconds(3))
        #expect(recovered.speed == 2)
        #expect(recovered.distance == 4)
    }

    @Test
    func delayedResetConfirmationDoesNotReportOldSpeed() throws {
        try wheel(1000, eventTime: 30 * 1024)
        try wheel(0, eventTime: 0, after: .seconds(1))
        try wheel(1, eventTime: 1024, after: .seconds(2))
        let confirmed = try wheel(1, eventTime: 1024, after: .seconds(64))
        #expect(confirmed.distance == 2)
        #expect(confirmed.speed == 0)
    }

    @Test(arguments: [UInt16(10240), 488])
    func severalOlderPacketsDoNotConfirmReset(lastEventTime: UInt16) throws {
        try wheel(100, eventTime: lastEventTime)
        for index in 1 ... 3 {
            try wheel(
                UInt32(96 + index),
                eventTime: lastEventTime &- UInt16((4 - index) * 1024),
                after: .milliseconds(100 * index)
            )
            #expect(device.distanceMeters == 0)
        }
        let next = try wheel(101, eventTime: lastEventTime &+ 1024, after: .seconds(1))
        #expect(next.distance == 2)
        #expect(next.speed == 2)
    }

    @Test
    func counterAndTimerResetWaitsForUnambiguousProgressWithoutLosingPendingDistance() throws {
        try wheel(1000, eventTime: 30 * 1024)
        try wheel(0, eventTime: 0, after: .seconds(1))
        let ambiguous = try wheel(1, eventTime: 1024, after: .seconds(2))
        #expect(ambiguous.distance == 0)
        let confirmed = try wheel(31, eventTime: 31 * 1024, after: .seconds(32))
        #expect(confirmed.distance == 62)
        #expect(confirmed.speed == 0)
        let next = try wheel(32, eventTime: 32 * 1024, after: .seconds(33))
        #expect(next.distance == 64)
        #expect(next.speed == 2)
    }

    @Test(arguments: [UInt32(0), 1, 98, 99, 100_000])
    func rejectedPacketDoesNotMoveDistanceBaseline(rejectedRevolutions: UInt32) throws {
        try wheel(100, eventTime: 10240)
        try wheel(rejectedRevolutions, eventTime: 8192, after: .milliseconds(250))
        #expect(device.distanceMeters == 0)
        let next = try wheel(101, eventTime: 11264, after: .seconds(1))
        #expect(next.distance == 2)
        #expect(next.speed == 2)
    }

    @Test
    func repeatedRejectedPacketDoesNotConfirmCounterReset() throws {
        try wheel(100, eventTime: 10240)
        for index in 1 ... 3 {
            try wheel(98, eventTime: 8192, after: .milliseconds(100 * index))
        }
        let next = try wheel(101, eventTime: 11264, after: .seconds(1))
        #expect(next.distance == 2)
        #expect(next.speed == 2)
    }

    @Test
    func reconnectClearsUnconfirmedCounterReset() throws {
        try wheel(100, eventTime: 10240)
        try wheel(98, eventTime: 8192, after: .milliseconds(100))
        device.resetMeasurements()
        try wheel(99, eventTime: 9216, after: .milliseconds(200))
        let next = try wheel(101, eventTime: 11264, after: .seconds(1))
        #expect(next.distance == 2)
        #expect(next.speed == 0)
    }

    @Test
    func speedExpiresWithoutAnotherPacket() {
        let sample = WorkoutDeviceCyclingSpeedSample(speed: 10, time: now)
        #expect(sample.value(now: now.advanced(by: .seconds(2))) == 10)
        #expect(sample.value(now: now.advanced(by: .seconds(3))) == 0)
        #expect(sample.value(now: now.advanced(by: .seconds(60))) == 0)
    }

    @Test
    func distanceStartsAtZeroAndSurvivesReconnect() throws {
        let (_, _, initialDistance) = try wheel(50000, eventTime: 1024)
        #expect(initialDistance == 0)
        try wheel(50005, eventTime: 2048)
        #expect(device.distanceMeters == 10)
        device.resetMeasurements()
        try wheel(2, eventTime: 1024)
        #expect(device.distanceMeters == 10)
        try wheel(3, eventTime: 2048)
        #expect(device.distanceMeters == 12)
        device.reset(preserveDistance: true)
        #expect(device.distanceMeters == 12)
        try wheel(3, eventTime: 2048)
        #expect(device.distanceMeters == 12)
        try wheel(4, eventTime: 3072)
        #expect(device.distanceMeters == 14)
        device.reset()
        #expect(device.distanceMeters == 0)
        try wheel(5000, eventTime: 4096)
        #expect(device.distanceMeters == 0)
    }

    @Test(arguments: [false, true])
    func recoversDisconnectedDistanceWithoutSpeedSpike(backgroundStop: Bool) throws {
        try wheel(100, eventTime: 0)
        try wheel(105, eventTime: 1024, after: .seconds(1))
        if backgroundStop {
            device.reset(preserveDistance: true)
        } else {
            device.resetMeasurements()
        }
        let resumed = try wheel(1605, eventTime: 1024, after: .seconds(301))
        #expect(resumed.distance == 3010)
        #expect(resumed.speed == 0)
        let next = try wheel(1610, eventTime: 2048, after: .seconds(302))
        #expect(next.distance == 3020)
        #expect(next.speed == 10)
    }

    @Test(arguments: [64, 65, 300])
    func distanceDoesNotDependOnShortEventTimer(seconds: Int) throws {
        try wheel(100, eventTime: 1024)
        let result = try wheel(
            UInt32(100 + 5 * seconds),
            eventTime: UInt16(truncatingIfNeeded: 1024 + seconds * 1024),
            after: .seconds(seconds)
        )
        #expect(result.distance == Double(10 * seconds))
        #expect(result.speed == 0)
    }

    @Test
    func rejectsResetDuringDisconnectAndAcceptsFollowingRevolutions() throws {
        try wheel(1000, eventTime: 0)
        try wheel(1005, eventTime: 1024, after: .seconds(1))
        device.reset(preserveDistance: true)
        let resumed = try wheel(0, eventTime: 0, after: .seconds(301))
        #expect(resumed.distance == 10)
        #expect(resumed.speed == 0)
        let next = try wheel(5, eventTime: 1024, after: .seconds(302))
        #expect(next.distance == 20)
        #expect(next.speed == 10)
    }

    @Test
    func counterWrapDuringDisconnectAddsDistanceOnlyOnce() throws {
        try wheel(.max - 4, eventTime: 65000)
        device.resetMeasurements()
        let packet = wheelMeasurement(revolutions: 5, eventTime: 65000)
        let resumed = try device.handleMeasurement(value: packet, now: now.advanced(by: .seconds(64)))
        #expect(resumed.distance == 20)
        #expect(resumed.speed == 0)
        _ = try device.handleMeasurement(value: packet, now: now.advanced(by: .seconds(65)))
        #expect(device.distanceMeters == 20)
    }

    @Test
    func rejectsImplausibleForwardCounterJump() throws {
        try wheel(100, eventTime: 0)
        let result = try wheel(100_000, eventTime: 1024, after: .seconds(1))
        #expect(result.distance == 0)
        #expect(result.speed == 0)
    }

    @Test
    func rejectsCounterResetAndResumesFromNewBaseline() throws {
        try wheel(1000, eventTime: 1024)
        try wheel(1001, eventTime: 2048)
        let (speed, _, _) = try wheel(0, eventTime: 3072)
        #expect(speed == 0)
        #expect(device.distanceMeters == 2)
        try wheel(1, eventTime: 4096)
        #expect(device.distanceMeters == 4)
    }

    @Test
    func distanceHandlesRolloverAndWheelSizeChanges() throws {
        try wheel(.max, eventTime: 65000)
        try wheel(0, eventTime: 488)
        #expect(device.distanceMeters == 2)
        device.setWheelCircumference(millimeters: 2500)
        try wheel(1, eventTime: 1512)
        #expect(device.distanceMeters == 4.5)
    }

    @Test
    func firstMeasurementOnlySeedsState() throws {
        let device = WorkoutDeviceCyclingSpeedCadence(wheelCircumference: 2105)
        let (speed, cadence, distance) = try device.handleMeasurement(value: crankMeasurement(
            revolutions: 10,
            eventTime: 1024
        ))
        #expect(cadence == nil)
        #expect(speed == nil)
        #expect(distance == nil)
    }

    @Test
    func calculatesCadenceFromCrankRevolutions() throws {
        let device = WorkoutDeviceCyclingSpeedCadence(wheelCircumference: 2105)
        _ = try device.handleMeasurement(value: crankMeasurement(revolutions: 10, eventTime: 1024))
        let (_, cadence, _) = try device.handleMeasurement(value: crankMeasurement(
            revolutions: 13,
            eventTime: 1024 + 2048
        ))
        #expect(cadence == 90)
    }

    @Test
    func handlesCrankRevolutionsWrapAround() throws {
        let device = WorkoutDeviceCyclingSpeedCadence(wheelCircumference: 2105)
        _ = try device.handleMeasurement(value: crankMeasurement(revolutions: 65535, eventTime: 65000))
        let (_, cadence, _) = try device.handleMeasurement(value: crankMeasurement(
            revolutions: 0,
            eventTime: 65000 &+ 1024
        ))
        #expect(cadence == 60)
    }

    @Test
    func ignoresMeasurementWithoutTimeProgress() throws {
        let device = WorkoutDeviceCyclingSpeedCadence(wheelCircumference: 2105)
        _ = try device.handleMeasurement(value: crankMeasurement(revolutions: 10, eventTime: 1024))
        _ = try device.handleMeasurement(value: crankMeasurement(revolutions: 11, eventTime: 1024 + 1024))
        let (_, cadence, _) = try device.handleMeasurement(value: crankMeasurement(
            revolutions: 11,
            eventTime: 1024 + 1024
        ))
        #expect(cadence == 60)
    }

    @Test
    func cadenceOnlySensorReportsNoSpeed() throws {
        let device = WorkoutDeviceCyclingSpeedCadence(wheelCircumference: 2105)
        _ = try device.handleMeasurement(value: crankMeasurement(revolutions: 10, eventTime: 1024))
        let (speed, cadence, _) = try device.handleMeasurement(value: crankMeasurement(
            revolutions: 11,
            eventTime: 1024 + 1024
        ))
        #expect(cadence == 60)
        #expect(speed == nil)
    }

    @Test
    func speedOnlySensorReportsNoCadence() throws {
        let device = WorkoutDeviceCyclingSpeedCadence(wheelCircumference: 2105)
        device.setWheelCircumference(millimeters: 2000)
        _ = try device.handleMeasurement(value: wheelMeasurement(revolutions: 100, eventTime: 1024))
        let (speed, cadence, distance) = try device.handleMeasurement(value: wheelMeasurement(
            revolutions: 105,
            eventTime: 1024 + 1024
        ))
        #expect(cadence == nil)
        #expect(try isEqual(#require(speed), 10, epsilon: 0.001))
        #expect(try isEqual(#require(distance), 10, epsilon: 0.001))
    }

    @Test
    func calculatesSpeedAndCadenceFromCombinedMeasurement() throws {
        let device = WorkoutDeviceCyclingSpeedCadence(wheelCircumference: 2105)
        device.setWheelCircumference(millimeters: 2000)
        _ = try device.handleMeasurement(value: wheelAndCrankMeasurement(wheelRevolutions: 100,
                                                                         wheelEventTime: 1024,
                                                                         crankRevolutions: 10,
                                                                         crankEventTime: 1024))
        let (speed, cadence, distance) = try device.handleMeasurement(value: wheelAndCrankMeasurement(
            wheelRevolutions: 105,
            wheelEventTime: 1024 + 1024,
            crankRevolutions: 11,
            crankEventTime: 1024 + 1024
        ))
        #expect(cadence == 60)
        #expect(try isEqual(#require(speed), 10, epsilon: 0.001))
        #expect(try isEqual(#require(distance), 10, epsilon: 0.001))
    }

    @Test
    func handlesWheelRevolutionsWrapAround() throws {
        let device = WorkoutDeviceCyclingSpeedCadence(wheelCircumference: 2105)
        device.setWheelCircumference(millimeters: 2000)
        _ = try device.handleMeasurement(value: wheelMeasurement(revolutions: .max, eventTime: 1024))
        let (speed, _, _) = try device.handleMeasurement(value: wheelMeasurement(
            revolutions: 4,
            eventTime: 1024 + 1024
        ))
        #expect(try isEqual(#require(speed), 10, epsilon: 0.001))
    }

    @Test
    func rejectsTruncatedMeasurement() {
        let device = WorkoutDeviceCyclingSpeedCadence(wheelCircumference: 2105)
        #expect(throws: (any Error).self) {
            try device.handleMeasurement(value: Data([0x02, 0x01]))
        }
    }
}

struct WorkoutDeviceCyclingMetricsStoreSuite {
    private let id = UUID()
    private let first = UUID()
    private let second = UUID()
    private let now = ContinuousClock.now

    @Test(arguments: [2999, 3000, 3001])
    func genericAndNamedSpeedUseTheSameSnapshotTime(milliseconds: Int) {
        var store = WorkoutDeviceCyclingMetricsStore()
        let sampledAt = ContinuousClock.now.advanced(by: .seconds(-60))
        let timestamp = sampledAt.advanced(by: .milliseconds(milliseconds))
        store.update(deviceId: id, speed: 10, distance: 100, now: sampledAt)
        let named = store.metricsByName(devices: [(id, "Bike")], now: timestamp)
        let generic = store.genericMetrics(deviceIds: [id], now: timestamp)
        #expect(generic.speed == (milliseconds < 3000 ? 10 : 0))
        #expect(named["bike"]?.speed == generic.speed)
        #expect(named["bike"]?.distance == generic.distance)
    }

    @Test
    func distanceOnlyUpdateDoesNotRefreshSpeed() {
        var store = WorkoutDeviceCyclingMetricsStore()
        store.update(deviceId: id, speed: 10, distance: 100, now: now)
        let later = now.advanced(by: .seconds(3))
        store.update(deviceId: id, speed: nil, distance: 120, now: later)
        let named = store.metricsByName(devices: [(id, "Bike")], now: later)
        #expect(store.genericMetrics(deviceIds: [id], now: later).speed == 0)
        #expect(named["bike"]?.speed == 0)
        #expect(store.genericMetrics(deviceIds: [id], now: later).distance == 120)
        #expect(named["bike"]?.distance == 120)
    }

    @Test
    func speedOnlyUpdateAndDisconnectUseOnlySpeedSamples() {
        var store = WorkoutDeviceCyclingMetricsStore()
        store.update(deviceId: id, speed: 10, distance: nil, now: now)
        let named = store.metricsByName(devices: [(id, "Bike")], now: now)
        #expect(store.genericMetrics(deviceIds: [id], now: now).speed == 10)
        #expect(named["bike"]?.speed == 10)
        #expect(named["bike"]?.distance == nil)
        store.disconnect(deviceId: id)
        #expect(store.genericMetrics(deviceIds: [id], now: now).speed == 0)
        #expect(store.metricsByName(devices: [(id, "Bike")], now: now)["bike"]?.speed == nil)
        store.update(deviceId: id, speed: 5, distance: nil, now: now)
        #expect(store.genericMetrics(deviceIds: [id], now: now).speed == 5)
        #expect(store.metricsByName(devices: [(id, "Bike")], now: now)["bike"]?.speed == 5)
    }

    @Test
    func genericMetricsKeepTheSameSensorAcrossDisconnects() {
        var store = WorkoutDeviceCyclingMetricsStore()
        let deviceIds = [first, second]
        store.update(deviceId: first, speed: 10, distance: 100, now: now)
        store.update(deviceId: second, speed: 20, distance: 900, now: now)
        #expect(store.genericMetrics(deviceIds: deviceIds, now: now).distance == 100)
        store.disconnect(deviceId: first)
        store.update(deviceId: second, speed: 20, distance: 920, now: now)
        #expect(store.genericMetrics(deviceIds: deviceIds, now: now) == .init(speed: 0, distance: 100))
        store.update(deviceId: first, speed: 0, distance: 120, now: now)
        #expect(store.genericMetrics(deviceIds: deviceIds, now: now).distance == 120)
        store.remove(deviceId: first)
        #expect(store.genericMetrics(deviceIds: [second], now: now).distance == 920)
        store.update(deviceId: second, speed: 20, distance: 940, now: now)
        #expect(store.genericMetrics(deviceIds: [second], now: now).distance == 940)
    }

    @Test
    func cadenceOnlySensorDoesNotBecomeGenericSource() {
        var store = WorkoutDeviceCyclingMetricsStore()
        let cadence = UUID()
        let wheel = UUID()
        store.update(deviceId: cadence, speed: nil, distance: nil, now: now)
        store.update(deviceId: wheel, speed: 10, distance: 100, now: now)
        #expect(store.genericMetrics(deviceIds: [cadence, wheel], now: now).distance == 100)
    }

    @Test(arguments: [false, true])
    func settingsOrderWinsOverPacketOrder(reversed: Bool) {
        var store = WorkoutDeviceCyclingMetricsStore()
        let samples = [(first, 10.0, 100.0), (second, 20.0, 900.0)]
        for (id, speed, distance) in reversed ? Array(samples.reversed()) : samples {
            store.update(deviceId: id, speed: speed, distance: distance, now: now)
        }
        #expect(store.genericMetrics(deviceIds: [first, second], now: now) == .init(speed: 10, distance: 100))
        let named = store.metricsByName(devices: [(first, "rpi8"), (second, "rpi5")], now: now)
        #expect(named["rpi8"] == .init(speed: 10, distance: 100))
        #expect(named["rpi5"] == .init(speed: 20, distance: 900))
    }

    @Test
    func delayedHigherPrioritySensorTakesPrecedenceWhenItReportsWheelData() {
        var store = WorkoutDeviceCyclingMetricsStore()
        store.update(deviceId: second, speed: 20, distance: 900, now: now)
        #expect(store.genericMetrics(deviceIds: [first, second], now: now).distance == 900)
        store.update(deviceId: first, speed: nil, distance: nil, now: now)
        #expect(store.genericMetrics(deviceIds: [first, second], now: now).distance == 900)
        store.update(deviceId: first, speed: 10, distance: 100, now: now)
        #expect(store.genericMetrics(deviceIds: [first, second], now: now) == .init(speed: 10, distance: 100))
    }

    @Test
    func settingsReorderAndDisableChangeOnlyTheGenericSource() {
        var store = WorkoutDeviceCyclingMetricsStore()
        store.update(deviceId: first, speed: 10, distance: 100, now: now)
        store.update(deviceId: second, speed: 20, distance: 900, now: now)
        #expect(store.genericMetrics(deviceIds: [second, first], now: now).distance == 900)
        #expect(store.genericMetrics(deviceIds: [first], now: now).distance == 100)
        #expect(store.genericMetrics(deviceIds: [second], now: now).distance == 900)
        #expect(store.genericMetrics(deviceIds: [], now: now) == .init(speed: 0, distance: 0))
        let named = store.metricsByName(devices: [(first, "One"), (second, "Two")], now: now)
        #expect(named["one"]?.distance == 100)
        #expect(named["two"]?.distance == 900)
    }

    @Test
    func expiredPrimarySpeedDoesNotSelectAnotherDistance() {
        var store = WorkoutDeviceCyclingMetricsStore()
        store.update(deviceId: first, speed: 10, distance: 100, now: now)
        let later = now.advanced(by: .seconds(3))
        store.update(deviceId: second, speed: 20, distance: 900, now: later)
        #expect(store.genericMetrics(deviceIds: [first, second], now: later) == .init(
            speed: 0,
            distance: 100
        ))
    }

    @Test
    func renamedSensorKeepsDistanceWithoutLeavingStaleNames() {
        var store = WorkoutDeviceCyclingMetricsStore()
        store.update(deviceId: id, speed: 10, distance: 100, now: now)
        #expect(store.metricsByName(devices: [(id, "Old")], now: now)["old"]?.distance == 100)
        let renamed = store.metricsByName(devices: [(id, "New")], now: now)
        #expect(renamed["new"]?.distance == 100)
        #expect(renamed["old"] == nil)
        #expect(store.metricsByName(devices: [], now: now).isEmpty)
        store.remove(deviceId: id)
        #expect(store.metricsByName(devices: [(id, "New")], now: now).isEmpty)
    }

    @Test
    func ambiguousNamesDoNotMixSensors() {
        var store = WorkoutDeviceCyclingMetricsStore()
        store.update(deviceId: first, speed: 10, distance: 100, now: now)
        store.update(deviceId: second, speed: 20, distance: 900, now: now)
        #expect(store.metricsByName(devices: [(first, "Bike"), (second, "bike")], now: now).isEmpty)
        let renamed = store.metricsByName(devices: [(first, "Bike"), (second, "Other")], now: now)
        #expect(renamed["bike"]?.distance == 100)
        #expect(renamed["other"]?.distance == 900)
    }

    @Test
    func speedExpiresButDistanceSurvivesDisconnect() {
        var store = WorkoutDeviceCyclingMetricsStore()
        store.update(deviceId: id, speed: 10, distance: 100, now: now)
        let stale = store.metricsByName(devices: [(id, "Bike")], now: now.advanced(by: .seconds(3)))
        #expect(stale["bike"]?.speed == 0)
        #expect(stale["bike"]?.distance == 100)
        store.disconnect(deviceId: id)
        let disconnected = store.metricsByName(devices: [(id, "Bike")], now: now)
        #expect(disconnected["bike"]?.speed == nil)
        #expect(disconnected["bike"]?.distance == 100)
    }
}
