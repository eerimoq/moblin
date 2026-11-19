@testable import Moblin
import Testing

struct ChzzkChatSegmentsSuite {
    @Test
    func resolvesAdjacentEmojisAndPreservesUnknownMarkers() {
        let segments = makeChzzkChatSegments(
            message: "안녕 {:wave:}{:wave:} {:missing:} 끝",
            emojis: ["wave": "https://example.com/wave.png"]
        )
        #expect(segments.map(\.id) == [0, 1, 2, 3, 4])
        #expect(segments.compactMap(\.text) == ["안녕 ", "{:missing:} ", "끝 "])
        #expect(segments.compactMap { $0.url?.name } == ["wave", "wave"])
    }
}
