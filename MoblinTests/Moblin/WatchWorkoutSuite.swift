import Foundation
@testable import Moblin
import Testing

@MainActor
struct WatchWorkoutSuite {
    @Test
    func cachedStatsKeepDistanceAcrossHeartRateUpdates() throws {
        let startedAt = Date(timeIntervalSince1970: 100)
        var stats = WatchProtocolWorkoutStats(workoutStartedAt: startedAt,
                                              workoutType: .poolSwimming,
                                              workoutActive: true,
                                              distance: 600)
        stats.merge(WatchProtocolWorkoutStats(heartRate: 135))
        let decoded = try JSONDecoder().decode(WatchProtocolWorkoutStats.self,
                                               from: JSONEncoder().encode(stats))
        #expect(decoded.distance == 600)
        #expect(decoded.heartRate == 135)
        #expect(decoded.workoutStartedAt == startedAt)
        #expect(decoded.workoutType == .poolSwimming)
        #expect(decoded.workoutActive == true)
        stats.merge(WatchProtocolWorkoutStats(workoutActive: false, distance: 0))
        #expect(stats.workoutActive == false)
        #expect(stats.distance == 0)
        #expect(stats.heartRate == 135)
    }

    @Test
    func oldWorkoutPacketsStillDecode() throws {
        let stats = try JSONDecoder().decode(WatchProtocolWorkoutStats.self,
                                             from: Data(#"{"heartRate":132,"distance":600}"#.utf8))
        #expect(stats.heartRate == 132)
        #expect(stats.distance == 600)
        #expect(stats.workoutStartedAt == nil)
        #expect(stats.workoutType == nil)
        #expect(stats.workoutActive == nil)
    }

    @Test
    func poolLengthPersistsAndOldSettingsUseDefault() throws {
        let settings = try JSONDecoder().decode(WatchSettings.self, from: Data("{}".utf8))
        #expect(settings.swimmingPoolLength == 25)
        for length in [6.0, 12.5, 25.0, 50.0] {
            settings.swimmingPoolLength = length
            let decoded = try JSONDecoder().decode(WatchSettings.self,
                                                   from: JSONEncoder().encode(settings))
            #expect(decoded.swimmingPoolLength == length)
        }
    }
}
