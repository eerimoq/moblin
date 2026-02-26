@testable import Moblin
import Testing

struct CameraManEffectSuite {
    private let stillSegmentStart: Double = CameraManEffect.movementDuration

    @Test
    func cropRectRemainsConstantDuringStillSegment() {
        let effect = CameraManEffect()
        let first = effect.cropRect(width: 1920, height: 1080, elapsed: stillSegmentStart)
        let second = effect.cropRect(width: 1920,
                                     height: 1080,
                                     elapsed: stillSegmentStart + CameraManEffect.stillDuration)
        #expect(first == second)
    }

    @Test
    func cropRectChangesDuringMovementSegment() {
        let effect = CameraManEffect()
        let first = effect.cropRect(width: 1920, height: 1080, elapsed: 0.2)
        let second = effect.cropRect(width: 1920, height: 1080, elapsed: CameraManEffect.movementDuration - 0.2)
        #expect(first != second)
    }
}
