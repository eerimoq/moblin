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

struct AdaptiveBitrateSuite {
    @Test
    func belaboxBasic() async throws {
        let handler = Handler()
        let belabox = AdaptiveBitrateSrtBela(targetBitrate: 5_000_000, delegate: handler)
        belabox.setSettings(settings: adaptiveBitrateBelaboxSettings)
        #expect(belabox.getCurrentBitrate() == 0)
        #expect(belabox.getCurrentMaximumBitrateInKbps() == 0)
        #expect(handler.bitrates.isEmpty)
    }
}
