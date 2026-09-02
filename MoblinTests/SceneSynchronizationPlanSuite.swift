import Foundation
@testable import Moblin
import Testing

struct SceneSynchronizationPlanSuite {
    private let accuracy = 0.000_001

    @Test
    func sceneSynchronizationIsDisabledByDefaultAndPersists() throws {
        let scene = SettingsScene(name: "Test")
        #expect(!scene.networkSourceSynchronizationEnabled)

        scene.networkSourceSynchronizationEnabled = true
        let decoded = try JSONDecoder().decode(SettingsScene.self, from: JSONEncoder().encode(scene))

        #expect(decoded.networkSourceSynchronizationEnabled)
    }

    @Test
    func noSourcesNeedsNoBuiltinDelay() {
        let plan = SceneSynchronizationPlan.make(sources: [])

        #expect(plan.builtinDelay == 0)
        #expect(plan.additionalDelays.isEmpty)
    }

    @Test
    func oneSourceKeepsItsConfiguredLatencyTarget() {
        let id = UUID()
        let plan = SceneSynchronizationPlan.make(sources: [
            .init(id: id, latency: 2.0, intrinsicDelay: 0.4),
        ])

        #expect(abs(plan.builtinDelay - 2.4) < accuracy)
        #expect(plan.additionalDelays[id] == 0)
    }

    @Test
    func sourcesAlignAtLargestEffectiveDelay() throws {
        let rtmp = UUID()
        let srt = UUID()
        let rist = UUID()
        let sources = [
            NetworkSourceDelay(id: rtmp, latency: 2.0, intrinsicDelay: 0.4),
            NetworkSourceDelay(id: srt, latency: 0.8, intrinsicDelay: 0.3),
            NetworkSourceDelay(id: rist, latency: 1.5, intrinsicDelay: 0.6),
        ]
        let plan = SceneSynchronizationPlan.make(sources: sources)

        #expect(abs(plan.builtinDelay - 2.4) < accuracy)
        #expect(plan.additionalDelays[rtmp] == 0)
        #expect(try abs(#require(plan.additionalDelays[srt]) - 1.3) < accuracy)
        #expect(try abs(#require(plan.additionalDelays[rist]) - 0.3) < accuracy)
        for source in sources {
            #expect(abs(source.effectiveDelay + plan.additionalDelays[source.id]! - plan.builtinDelay) <
                accuracy)
        }
    }

    @Test
    func equalEffectiveDelaysNeedNoAdditionalDelay() {
        let first = UUID()
        let second = UUID()
        let plan = SceneSynchronizationPlan.make(sources: [
            .init(id: first, latency: 1.0, intrinsicDelay: 0.5),
            .init(id: second, latency: 0.5, intrinsicDelay: 1.0),
        ])

        #expect(abs(plan.builtinDelay - 1.5) < accuracy)
        #expect(plan.additionalDelays[first] == 0)
        #expect(plan.additionalDelays[second] == 0)
    }
}
