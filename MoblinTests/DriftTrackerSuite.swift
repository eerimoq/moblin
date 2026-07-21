@testable import Moblin
import Testing

struct DriftTrackerSuite {
    @Test
    func driftIsClampedWhenAdjustingUpRepeatedly() {
        let tracker = DriftTracker(media: "video", name: "test", targetFillLevel: 0.1)
        // Simulate chronic under-fill: setDrift is only path without sample buffers.
        // Drive adjustDrift via update with empty buffers (fill ~0).
        var last: Double?
        for i in 0 ..< 50 {
            let pts = Double(i) * 25.0
            if let drift = tracker.update(pts, []) {
                last = drift
            }
        }
        // maxAbsDrift = max(1.0, 0.1 * 4) = 1.0
        #expect(last != nil)
        #expect(abs(last!) <= 1.0001)
        #expect(abs(tracker.getDrift()) <= 1.0001)
    }

    @Test
    func setDriftIsClamped() {
        let tracker = DriftTracker(media: "video", name: "test", targetFillLevel: 0.5)
        tracker.setDrift(drift: 100)
        #expect(abs(tracker.getDrift() - 2.0) < 0.0001)
        tracker.setDrift(drift: -100)
        #expect(abs(tracker.getDrift() + 2.0) < 0.0001)
    }
}
