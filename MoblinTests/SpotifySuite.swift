@testable import Moblin
import Testing

struct SpotifySuite {
    @Test
    func makeSpotifyTracks() {
        let track = "1jrARDhheF2nrDEevG9rmo"
        let expected = "spotify:track:\(track)"
        #expect(makeSpotifyTrack(value: "") == nil)
        #expect(makeSpotifyTrack(value: track) == expected)
        #expect(makeSpotifyTrack(value: expected) == expected)
        #expect(makeSpotifyTrack(value: "https://open.spotify.com/track/\(track)?si=915f9e8f387f4a9c") ==
            expected)
    }
}
