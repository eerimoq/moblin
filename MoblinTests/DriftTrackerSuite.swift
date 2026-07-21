@testable import Moblin
import Testing

struct DriftTrackerSuite {
    @Test
    func setDriftIsClamped() {
        let tracker = DriftTracker(media: "video", name: "test", targetFillLevel: 0.5)
        tracker.setDrift(drift: 100)
        #expect(abs(tracker.getDrift() - 2.0) < 0.0001)
        tracker.setDrift(drift: -100)
        #expect(abs(tracker.getDrift() + 2.0) < 0.0001)
    }

    @Test
    func setDriftRespectsTargetFillLevel() {
        let tracker = DriftTracker(media: "audio", name: "test", targetFillLevel: 2.0)
        tracker.setDrift(drift: 100)
        #expect(abs(tracker.getDrift() - 8.0) < 0.0001)
    }
}
