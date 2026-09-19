@testable import Moblin
import Testing

struct DriftTrackerSuite {
    @Test
    func steadyLevelDoesNotAdjust() {
        let tracker = DriftTracker(media: "video", name: "", targetFillLevel: 1.0)
        let adjustments = drive(tracker, from: 0, to: 120) { time in time + 1.0 }
        #expect(adjustments.isEmpty)
        #expect(tracker.getDrift() == 0)
    }

    @Test
    func stallBurstDoesNotAdjust() {
        let tracker = DriftTracker(media: "video", name: "", targetFillLevel: 1.0)
        var adjustments = drive(tracker, from: 0, to: 50) { time in time + 1.0 }
        adjustments += drive(tracker, from: 60, to: 65) { time in 51.0 + (time - 60) * 3.0 }
        adjustments += drive(tracker, from: 65, to: 150) { time in time + 1.0 }
        #expect(adjustments.isEmpty)
        #expect(tracker.getDrift() == 0)
    }

    @Test
    func sustainedJumpAdjustsToTarget() {
        let tracker = DriftTracker(media: "video", name: "", targetFillLevel: 1.0)
        var adjustments = drive(tracker, from: 0, to: 50) { time in time + 1.0 }
        adjustments += drive(tracker, from: 50, to: 150) { time in time }
        #expect(adjustments.count == 1)
        #expect(abs(tracker.getDrift() - 1.0) < 0.01)
    }

    @Test
    func otherMediaDriftIsIncludedInFillLevel() {
        let tracker = DriftTracker(media: "video", name: "", targetFillLevel: 1.0)
        tracker.setDrift(drift: 0.5)
        let adjustments = drive(tracker, from: 0, to: 120) { time in time + 0.5 }
        #expect(adjustments.isEmpty)
        #expect(tracker.getDrift() == 0.5)
    }

    @Test
    func targetChangeWaitsForNewSamples() {
        let tracker = DriftTracker(media: "video", name: "", targetFillLevel: 1.0)
        var adjustments = drive(tracker, from: 0, to: 50) { time in time + 1.0 }
        tracker.setTargetFillLevel(targetFillLevel: 2.0)
        adjustments += drive(tracker, from: 50, to: 65) { time in time + 1.0 }
        #expect(adjustments.isEmpty)
        adjustments += drive(tracker, from: 65, to: 100) { time in time + 1.0 }
        #expect(adjustments.count == 1)
        #expect(abs(tracker.getDrift() - 1.0) < 0.01)
    }
}

private func drive(_ tracker: DriftTracker,
                   from: Double,
                   to: Double,
                   newest: (Double) -> Double) -> [Double]
{
    var adjustments: [Double] = []
    var time = from
    while time < to {
        if let drift = tracker.update(time, newest(time)) {
            adjustments.append(drift)
        }
        time += 0.6
    }
    return adjustments
}
