import AVFoundation
import Collections
@testable import Moblin
import Testing

private class Handler {
    var bitrates: Deque<UInt32> = []
}

extension Handler: AdaptiveBitrateDelegate {
    func adaptiveBitrateSetVideoStreamBitrate(bitrate: UInt32) {
        bitrates.append(bitrate)
    }
}

private func makeStats(bitrate: Int64) -> StreamStats {
    return StreamStats(rttMs: 30,
                       packetsInFlight: 15,
                       transportBitrate: bitrate,
                       latency: 3000,
                       mbpsSendRate: Double(bitrate),
                       relaxed: false)
}

private func update(belabox: AdaptiveBitrateSrtBelabox, bitrate: Int64) async throws {
    try await sleep(milliSeconds: 20)
    belabox.update(stats: makeStats(bitrate: bitrate))
}

struct AdaptiveBitrateSuite {
    @Test
    func belaboxStartAtTarget() async throws {
        let handler = Handler()
        let belabox = AdaptiveBitrateSrtBelabox(targetBitrate: 5_000_000, delegate: handler)
        belabox.setSettings(settings: adaptiveBitrateBelaboxSettings)
        #expect(belabox.getCurrentBitrate() == 5_000_000)
        #expect(belabox.getCurrentMaximumBitrateInKbps() == 5000)
        #expect(handler.bitrates.isEmpty)
        try await update(belabox: belabox, bitrate: 5_000_000)
        #expect(belabox.getCurrentBitrate() == 5_000_000)
    }

    @Test
    func belaboxTransportBitrateLimit() async throws {
        let handler = Handler()
        let belabox = AdaptiveBitrateSrtBelabox(targetBitrate: 5_000_000, delegate: handler)
        belabox.setSettings(settings: adaptiveBitrateBelaboxSettings)
        #expect(belabox.getCurrentBitrate() == 5_000_000)
        #expect(belabox.getCurrentMaximumBitrateInKbps() == 5000)
        #expect(handler.bitrates.isEmpty)
        let transportBitrate1Mbps: Int64 = 1_000_000
        try await update(belabox: belabox, bitrate: transportBitrate1Mbps)
        #expect(handler.bitrates.popFirst() == 2_000_000)
        let transportBitrate5Mbps: Int64 = 5_000_000
        while belabox.getCurrentBitrate() != 5_000_000 {
            try await update(belabox: belabox, bitrate: transportBitrate5Mbps)
        }
        try await update(belabox: belabox, bitrate: transportBitrate5Mbps)
        #expect(belabox.getCurrentBitrate() == 5_000_000)
        #expect(handler.bitrates.last == 5_000_000)
    }
}
