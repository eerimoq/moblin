import Foundation
@testable import Moblin
import Testing

struct WorkoutDeviceCrankCadenceSuite {
    @Test
    func reportsNothingWithoutCrankData() {
        let crankCadence = WorkoutDeviceCrankCadence()
        let now = ContinuousClock.now
        #expect(crankCadence.update(revolutions: nil, time: nil, now: now) == nil)
        #expect(crankCadence.update(revolutions: nil,
                                    time: nil,
                                    now: now.advanced(by: .seconds(10))) == nil)
    }

    @Test
    func firstCrankMeasurementReportsNothing() {
        let crankCadence = WorkoutDeviceCrankCadence()
        let now = ContinuousClock.now.advanced(by: .seconds(10))
        #expect(crankCadence.update(revolutions: 10, time: 1024, now: now) == nil)
    }

    @Test
    func reportsZeroWhenCrankStops() {
        let crankCadence = WorkoutDeviceCrankCadence()
        var now = ContinuousClock.now
        _ = crankCadence.update(revolutions: 10, time: 1024, now: now)
        now = now.advanced(by: .seconds(1))
        #expect(crankCadence.update(revolutions: 11, time: 2048, now: now) == 60)
        for _ in 0 ..< 3 {
            now = now.advanced(by: .seconds(4))
            _ = crankCadence.update(revolutions: 11, time: 2048, now: now)
        }
        #expect(crankCadence.update(revolutions: 11, time: 2048, now: now) == 0)
    }

    @Test
    func forgetsCadenceOnReset() {
        let crankCadence = WorkoutDeviceCrankCadence()
        let now = ContinuousClock.now
        _ = crankCadence.update(revolutions: 10, time: 1024, now: now)
        #expect(crankCadence.update(revolutions: 11,
                                    time: 2048,
                                    now: now.advanced(by: .seconds(1))) == 60)
        crankCadence.reset()
        #expect(crankCadence.update(revolutions: 12,
                                    time: 3072,
                                    now: now.advanced(by: .seconds(2))) == nil)
    }
}
