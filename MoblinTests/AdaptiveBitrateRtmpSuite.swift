import Collections
import Foundation
@testable import Moblin
import Testing

private class MockAdaptiveBitrateDelegate: AdaptiveBitrateDelegate {
    var bitrates: Deque<UInt32> = []

    func adaptiveBitrateSetVideoStreamBitrate(bitrate: UInt32) {
        bitrates.append(bitrate)
    }
}

struct AdaptiveBitrateRtmpSuite {
    @Test
    func dropsBitrateOnHighBufferUtilization() {
        let delegate = MockAdaptiveBitrateDelegate()
        let abr = AdaptiveBitrateRtmp(targetBitrate: 6_000_000, delegate: delegate)

        let stats = StreamStats(
            rttMs: 120,
            packetsInFlight: 0,
            transportBitrate: nil,
            latency: nil,
            mbpsSendRate: nil,
            relaxed: nil,
            sendBufferUtilization: 0.91 // Acima do threshold 0.82
        )

        abr.update(stats: stats)

        guard let last = delegate.bitrates.last else {
            Issue.record("Deveria ter disparado o delegate")
            return
        }
        #expect(last < 6_000_000, "Deveria ter reduzido o bitrate")
    }

    @Test
    func respectsKeyframeProtectionWindow() {
        let delegate = MockAdaptiveBitrateDelegate()
        let abr = AdaptiveBitrateRtmp(targetBitrate: 5_000_000, delegate: delegate)

        // Simula keyframe recente
        abr.notifyKeyframeSent()

        let stats = StreamStats(
            rttMs: 120,
            packetsInFlight: 0,
            transportBitrate: nil,
            latency: nil,
            mbpsSendRate: nil,
            relaxed: nil,
            sendBufferUtilization: 0.95 // Congestionamento forte
        )

        abr.update(stats: stats)

        // Não deve ter droppado por causa da proteção
        #expect(delegate.bitrates.isEmpty, "Não deve dropar bitrate dentro da janela de keyframe")
    }
}
