@testable import Moblin
import Testing

struct CameraManEffectSuite {
    @Test
    func staysStillSometimes() {
        let effect = CameraManEffect()
        let first = effect.cropRect(width: 1920, height: 1080, elapsed: 3.1)
        let second = effect.cropRect(width: 1920, height: 1080, elapsed: 3.9)
        #expect(first == second)
    }

    @Test
    func movesBetweenStillSegments() {
        let effect = CameraManEffect()
        let first = effect.cropRect(width: 1920, height: 1080, elapsed: 0.2)
        let second = effect.cropRect(width: 1920, height: 1080, elapsed: 1.2)
        #expect(first != second)
    }
}
