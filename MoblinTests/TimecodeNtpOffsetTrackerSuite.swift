@testable import Moblin
import Testing

struct TimecodeNtpOffsetTrackerSuite {
    @Test
    func oneShotModeKeepsInitialOffset() {
        var tracker = TimecodeNtpOffsetTracker(continuousCorrection: false)
        let first = tracker.update(ntpSeconds: 1000.0, hostSeconds: 100.0)
        #expect(first.didWrite)
        #expect(first.offset == 900.0)
        let second = tracker.update(ntpSeconds: 1102.0, hostSeconds: 200.0)
        #expect(!second.didWrite)
        #expect(second.offset == 900.0)
        #expect(tracker.correctionCount == 1)
        #expect(!tracker.needsSample(hostSeconds: 300.0))
    }

    @Test
    func continuousModeTracksOffsetWithEma() {
        var tracker = TimecodeNtpOffsetTracker(continuousCorrection: true,
                                               minUpdateIntervalSeconds: 0.0,
                                               emaAlpha: 0.5,
                                               maxStepSeconds: 10.0)
        _ = tracker.update(ntpSeconds: 1000.0, hostSeconds: 100.0)
        let second = tracker.update(ntpSeconds: 1102.0, hostSeconds: 200.0)
        #expect(second.didWrite)
        #expect(abs(second.offset - 901.0) < 0.0001)
        #expect(abs((tracker.lastCorrectionDelta ?? 0) - 1.0) < 0.0001)
    }

    @Test
    func continuousModeClampsLargeSteps() {
        var tracker = TimecodeNtpOffsetTracker(continuousCorrection: true,
                                               minUpdateIntervalSeconds: 0.0,
                                               emaAlpha: 1.0,
                                               maxStepSeconds: 0.05)
        _ = tracker.update(ntpSeconds: 1000.0, hostSeconds: 100.0)
        let stepped = tracker.update(ntpSeconds: 1102.0, hostSeconds: 200.0)
        #expect(stepped.didWrite)
        #expect(abs(stepped.offset - 900.05) < 0.0001)
    }

    @Test
    func continuousModeRespectsUpdateInterval() {
        var tracker = TimecodeNtpOffsetTracker(continuousCorrection: true,
                                               minUpdateIntervalSeconds: 5.0,
                                               emaAlpha: 1.0,
                                               maxStepSeconds: 10.0)
        _ = tracker.update(ntpSeconds: 1000.0, hostSeconds: 100.0)
        #expect(!tracker.needsSample(hostSeconds: 104.0))
        let early = tracker.update(ntpSeconds: 1104.0, hostSeconds: 104.0)
        #expect(!early.didWrite)
        #expect(tracker.needsSample(hostSeconds: 105.0))
        let later = tracker.update(ntpSeconds: 1105.0, hostSeconds: 105.0)
        #expect(later.didWrite)
    }

    @Test
    func resetClearsState() {
        var tracker = TimecodeNtpOffsetTracker(continuousCorrection: true)
        _ = tracker.update(ntpSeconds: 1000.0, hostSeconds: 100.0)
        tracker.reset()
        #expect(tracker.offset == nil)
        #expect(tracker.correctionCount == 0)
        #expect(tracker.needsSample(hostSeconds: 0.0))
    }
}
