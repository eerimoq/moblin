import AVFoundation
@testable import Moblin
import Testing

struct CmTimeSuite {
    @Test
    func secondsIsValueDividedByTimescale() {
        #expect(CMTime(value: 3, timescale: 2).seconds == 1.5)
        #expect(CMTime(value: 1, timescale: 1000).seconds == 0.001)
        #expect(CMTime(value: 90000, timescale: 90000).seconds == 1)
    }

    @Test
    func sameTimeHasDifferentValuePerTimescale() {
        let oneSecond = CMTime(value: 1, timescale: 1)
        let oneSecondInMilliseconds = CMTime(value: 1000, timescale: 1000)
        #expect(oneSecond == oneSecondInMilliseconds)
        #expect(oneSecond.seconds == oneSecondInMilliseconds.seconds)
        #expect(oneSecond.value != oneSecondInMilliseconds.value)
    }

    @Test
    func comparisonUsesTimeNotValue() {
        #expect(CMTime(value: 1, timescale: 1) > CMTime(value: 999, timescale: 1000))
        #expect(CMTime(value: 1, timescale: 3) == CMTime(value: 2, timescale: 6))
    }

    @Test
    func additionWithDifferentTimescalesUsesTheFinerTimescale() {
        let sum = CMTime(value: 2000, timescale: 1000) + CMTime(value: 5, timescale: 1)
        #expect(sum.value == 7000)
        #expect(sum.timescale == 1000)
        #expect(sum.seconds == 7)
    }

    @Test
    func additionWithUnrelatedTimescalesMultipliesThem() {
        let sum = CMTime(value: 1, timescale: 3) + CMTime(value: 1, timescale: 1000)
        #expect(sum.value == 1003)
        #expect(sum.timescale == 3000)
    }

    @Test
    func secondsInitializerQuantizesToItsTimescale() {
        #expect(CMTime(seconds: 1.5).value == 1500)
        #expect(CMTime(seconds: 1.5).timescale == 1000)
        #expect(CMTime(seconds: 1.0 / 3).seconds == 0.333)
        #expect(CMTime(seconds: 0.0001).seconds == 0)
        #expect(CMTime(seconds: 1.0 / 3, preferredTimescale: 90000).value == 30000)
    }

    @Test
    func secondsInitializerTruncatesTowardsZero() {
        #expect(CMTime(seconds: 0.0019, preferredTimescale: 1000).value == 1)
        #expect(CMTime(seconds: 0.002, preferredTimescale: 1000).value == 2)
        #expect(CMTime(seconds: -0.0015, preferredTimescale: 1000).value == -1)
    }
}
