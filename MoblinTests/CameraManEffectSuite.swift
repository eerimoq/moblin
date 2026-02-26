@testable import Moblin
import Testing

struct CameraManEffectSuite {
    @Test
    func cropRectRemainsConstantDuringStillSegment() {
        let effect = CameraManEffect()
        let firstSegment = effect.segmentInfo(elapsed: 0)
        let stillSegmentStart = firstSegment.movementDuration
        let first = effect.cropRect(width: 1920, height: 1080, elapsed: stillSegmentStart + 0.05)
        let second = effect.cropRect(width: 1920,
                                     height: 1080,
                                     elapsed: stillSegmentStart + firstSegment.stillDuration - 0.05)
        #expect(first == second)
    }

    @Test
    func cropRectChangesDuringMovementSegment() {
        let effect = CameraManEffect()
        let firstSegment = effect.segmentInfo(elapsed: 0)
        let first = effect.cropRect(width: 1920, height: 1080, elapsed: firstSegment.movementDuration * 0.15)
        let second = effect.cropRect(width: 1920, height: 1080, elapsed: firstSegment.movementDuration * 0.75)
        #expect(first != second)
    }

    @Test
    func segmentTimingsAreRandomized() {
        let effect = CameraManEffect()
        let firstSegment = effect.segmentInfo(elapsed: 0)
        var elapsed = firstSegment.movementDuration + firstSegment.stillDuration + 0.01
        var hasDifferentMovementDuration = false
        var hasDifferentStillDuration = false
        var hasDifferentSpeedFactor = false
        for _ in 0 ..< 10 {
            let nextSegment = effect.segmentInfo(elapsed: elapsed)
            hasDifferentMovementDuration = hasDifferentMovementDuration
                || firstSegment.movementDuration != nextSegment.movementDuration
            hasDifferentStillDuration = hasDifferentStillDuration
                || firstSegment.stillDuration != nextSegment.stillDuration
            hasDifferentSpeedFactor = hasDifferentSpeedFactor
                || firstSegment.speedFactor != nextSegment.speedFactor
            elapsed += nextSegment.movementDuration + nextSegment.stillDuration + 0.01
        }
        #expect(hasDifferentMovementDuration)
        #expect(hasDifferentStillDuration)
        #expect(hasDifferentSpeedFactor)
    }
}
