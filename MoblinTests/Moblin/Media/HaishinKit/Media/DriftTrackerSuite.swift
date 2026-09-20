@testable import Moblin
import Testing

struct DriftTrackerSuite {
    @Test
    func steadyLevelDoesNotAdjust() {
        let tracker = createTracker()
        let adjustments = drive(tracker, from: 0, to: 120, video: { time in time + 1.0 })
        #expect(adjustments.isEmpty)
        #expect(tracker.getDrift() == 0)
    }

    @Test
    func stallBurstDoesNotAdjust() {
        let tracker = createTracker()
        var adjustments = drive(tracker, from: 0, to: 50, video: { time in time + 1.0 })
        adjustments += drive(tracker, from: 60, to: 65, video: { time in 51.0 + (time - 60) * 3.0 })
        adjustments += drive(tracker, from: 65, to: 150, video: { time in time + 1.0 })
        #expect(adjustments.isEmpty)
        #expect(tracker.getDrift() == 0)
    }

    @Test
    func sustainedJumpAdjustsToTarget() {
        let tracker = createTracker()
        var adjustments = drive(tracker, from: 0, to: 50, video: { time in time + 1.0 })
        adjustments += drive(tracker, from: 50, to: 150, video: { time in time })
        #expect(adjustments.count == 1)
        #expect(abs(tracker.getDrift() - 1.0) < 0.01)
    }

    @Test
    func initialDriftIsIncludedInFillLevel() {
        let tracker = createTracker()
        tracker.setDrift(drift: 0.5)
        let adjustments = drive(tracker, from: 0, to: 120, video: { time in time + 0.5 })
        #expect(adjustments.isEmpty)
        #expect(tracker.getDrift() == 0.5)
    }

    @Test
    func audioAndVideoShareOneDrift() {
        let tracker = createTracker()
        var adjustments = drive(tracker,
                                from: 0,
                                to: 50,
                                audio: { time in time + 1.0 },
                                video: { time in time + 1.0 })
        adjustments += drive(tracker, from: 50, to: 150, audio: { time in time }, video: { time in time })
        #expect(adjustments.count == 1)
        #expect(abs(tracker.getDrift() - 1.0) < 0.01)
    }

    @Test
    func leadingMediaKeepsExtraBuffer() {
        let tracker = createTracker()
        let adjustments = drive(tracker,
                                from: 0,
                                to: 200,
                                audio: { time in time + 1.5 },
                                video: { time in time + 1.0 })
        #expect(adjustments.isEmpty)
        #expect(tracker.getDrift() == 0)
    }

    @Test
    func laggingMediaIsHeldAtTarget() {
        let tracker = createTracker()
        let adjustments = drive(tracker,
                                from: 0,
                                to: 200,
                                audio: { time in time + 1.0 },
                                video: { time in time + 0.5 })
        #expect(adjustments.count == 1)
        #expect(abs(tracker.getDrift() - 0.5) < 0.01)
    }

    @Test
    func staleMediaIsIgnored() {
        let tracker = createTracker()
        var adjustments = drive(tracker,
                                from: 0,
                                to: 50,
                                audio: { time in time + 1.0 },
                                video: { time in time + 1.0 })
        adjustments += drive(tracker, from: 50, to: 150, video: { time in time + 2.0 })
        #expect(adjustments.count == 1)
        #expect(abs(tracker.getDrift() + 1.0) < 0.01)
    }

    @Test
    func mediaWithTooFewSamplesIsIgnored() {
        let tracker = createTracker()
        var adjustments = drive(tracker, from: 0, to: 50, video: { time in time + 1.0 })
        adjustments += drive(
            tracker,
            from: 50,
            to: 55,
            audio: { time in time + 3.0 },
            video: { time in time }
        )
        adjustments += drive(tracker, from: 55, to: 150, video: { time in time })
        #expect(adjustments.count == 1)
        #expect(abs(tracker.getDrift() - 1.0) < 0.01)
    }

    @Test
    func unknownMediaIsIgnored() {
        let tracker = DriftTracker(name: "")
        tracker.addMedia(.video, targetFillLevel: 1.0)
        let adjustments = drive(tracker, from: 0, to: 120, audio: { time in time + 5.0 })
        #expect(adjustments.isEmpty)
        #expect(tracker.getDrift() == 0)
    }
}

private func createTracker() -> DriftTracker {
    let tracker = DriftTracker(name: "")
    tracker.addMedia(.audio, targetFillLevel: 1.0)
    tracker.addMedia(.video, targetFillLevel: 1.0)
    return tracker
}

private func drive(_ tracker: DriftTracker,
                   from: Double,
                   to: Double,
                   audio: ((Double) -> Double)? = nil,
                   video: ((Double) -> Double)? = nil) -> [Double]
{
    var adjustments: [Double] = []
    var time = from
    while time < to {
        for (media, newest) in [(DriftTrackerMedia.audio, audio), (DriftTrackerMedia.video, video)] {
            guard let newest else {
                continue
            }
            let drift = tracker.getDrift()
            tracker.update(media: media, time, newest(time))
            if tracker.getDrift() != drift {
                adjustments.append(tracker.getDrift())
            }
        }
        time += 0.6
    }
    return adjustments
}
