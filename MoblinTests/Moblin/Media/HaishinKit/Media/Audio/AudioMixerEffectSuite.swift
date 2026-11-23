import AudioToolbox
@testable import Moblin
import Testing

struct AudioMixerEffectSuite {
    @Test
    func latencyIsImpulseDelay() throws {
        let limiter = try #require(makeAudioMixerLimiter())
        var output: [Float] = []
        for block in 0 ..< 4 {
            var left = createBlock(block) { $0 == 1000 ? 0.25 : 0 }
            var right = left
            limiter.process(&left, &right)
            output += left
        }
        #expect(output.indices.filter { output[$0] != 0 } == [1000 + Int(limiter.latency)])
    }

    @Test
    func limiterKeepsLoudSineBelowFullScale() throws {
        let limiter = try #require(makeAudioMixerLimiter())
        var peak: Float = 0
        for block in 0 ..< 100 {
            var left = createBlock(block) { 4 * createSine(0, $0) }
            var right = left
            limiter.process(&left, &right)
            if block >= 25 {
                peak = max(peak, left.map { abs($0) }.max() ?? 0)
            }
        }
        #expect(peak > 0.5)
        #expect(peak < 1)
    }

    @Test
    func failedRenderIsSilence() throws {
        let limiter = try #require(makeAudioMixerLimiter())
        var left = createBlock(0) { _ in 0.5 }
        var right = left
        limiter.process(&left, &right)
        AudioUnitUninitialize(limiter.audioUnit)
        left = createBlock(1) { _ in 0.5 }
        right = left
        limiter.process(&left, &right)
        let failed = left + right
        AudioUnitInitialize(limiter.audioUnit)
        left = createBlock(2) { _ in 0 }
        right = left
        limiter.process(&left, &right)
        let silence = [Float](repeating: 0, count: 2 * audioMixerFramesPerBlock)
        #expect(failed == silence)
        #expect(left + right == silence)
    }
}

private func createBlock(_ index: Int, _ value: (Int) -> Float) -> [Float] {
    (0 ..< audioMixerFramesPerBlock).map { value(index * audioMixerFramesPerBlock + $0) }
}
