import AVFoundation
@testable import Moblin
import Testing

struct CameraUtilsSuite {
    private let exposures = [1000, 500, 250, 125, 60].map { CMTime(value: 1, timescale: CMTimeScale($0)) }

    @Test
    func factorEndsAreFastestAndSlowestExposures() {
        #expect(factorToExposure(exposures: exposures, factor: 0) == CMTime(value: 1, timescale: 1000))
        #expect(factorToExposure(exposures: exposures, factor: 1) == CMTime(value: 1, timescale: 60))
        #expect(factorToExposure(exposures: exposures, factor: 0.5) == CMTime(value: 1, timescale: 250))
    }

    @Test
    func factorOutsideRangeIsClamped() {
        #expect(factorToExposure(exposures: exposures, factor: -1) == CMTime(value: 1, timescale: 1000))
        #expect(factorToExposure(exposures: exposures, factor: 2) == CMTime(value: 1, timescale: 60))
    }

    @Test
    func factorSnapsToNearestExposure() {
        #expect(factorToExposure(exposures: exposures, factor: 0.3) == CMTime(value: 1, timescale: 500))
        #expect(factorToExposure(exposures: exposures, factor: 0.6) == CMTime(value: 1, timescale: 250))
    }

    @Test
    func everyExposureRoundTripsThroughItsFactor() {
        for exposure in exposures {
            let factor = factorFromExposure(exposures: exposures, exposure: exposure)
            #expect(factorToExposure(exposures: exposures, factor: factor) == exposure)
        }
    }

    @Test
    func exposureFromDeviceIsNearestInLogSpace() {
        let exposure = factorFromExposure(exposures: exposures, exposure: CMTime(value: 1, timescale: 130))
        #expect(factorToExposure(exposures: exposures, factor: exposure) == CMTime(value: 1, timescale: 125))
        let slow = factorFromExposure(exposures: exposures, exposure: CMTime(value: 1, timescale: 4))
        #expect(factorToExposure(exposures: exposures, factor: slow) == CMTime(value: 1, timescale: 60))
        let fast = factorFromExposure(exposures: exposures, exposure: CMTime(value: 1, timescale: 8000))
        #expect(factorToExposure(exposures: exposures, factor: fast) == CMTime(value: 1, timescale: 1000))
    }

    @Test
    func invalidExposureIsFastest() {
        #expect(factorFromExposure(exposures: exposures, exposure: .zero) == 0)
        #expect(factorFromExposure(exposures: exposures, exposure: .invalid) == 0)
    }

    @Test
    func stepIsOnePerExposure() {
        #expect(exposureFactorStep(exposures: exposures) == 0.25)
        #expect(exposureFactorStep(exposures: [CMTime(value: 1, timescale: 60)]) == 1)
        #expect(exposureFactorStep(exposures: []) == 1)
    }

    @Test
    func singleExposureIsAlwaysUsed() {
        let exposures = [CMTime(value: 1, timescale: 30)]
        #expect(factorToExposure(exposures: exposures, factor: 0) == CMTime(value: 1, timescale: 30))
        #expect(factorToExposure(exposures: exposures, factor: 1) == CMTime(value: 1, timescale: 30))
        #expect(factorFromExposure(exposures: exposures, exposure: CMTime(value: 1, timescale: 30)) == 0)
    }

    @Test
    func exposureIsFormattedAsFractionOfSecond() {
        #expect(formatExposure(exposure: CMTime(value: 1, timescale: 125)) == "1/125")
        #expect(formatExposure(exposure: CMTime(value: 1, timescale: 8000)) == "1/8000")
        #expect(formatExposure(exposure: CMTime(seconds: 0.02)) == "1/50")
        #expect(formatExposure(exposure: CMTime(seconds: 1 / 71)) == "1/71")
        #expect(formatExposure(exposure: .zero) == "")
        #expect(formatExposure(exposure: .invalid) == "")
    }
}
