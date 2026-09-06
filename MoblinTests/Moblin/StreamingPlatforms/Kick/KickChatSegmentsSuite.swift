import Foundation
@testable import Moblin
import Testing

struct KickChatSegmentsSuite {
    private func createSegments(_ message: String, emotes: [String] = []) -> [ChatPostSegment] {
        var id = 0
        return createKickSegments(message: message, emotesManager: makeEmotes(emotes), id: &id)
    }

    @Test
    func noEmotes() {
        let segments = createSegments("hello world")
        #expect(texts(segments) == ["hello ", "world "])
        #expect(emoteNames(segments) == [nil, nil])
    }

    @Test
    func emoteInTheMiddle() {
        let segments = createSegments("hey [emote:37226:KEKW] there")
        #expect(texts(segments) == ["hey ", nil, "there "])
        #expect(emoteNames(segments) == [nil, "fullsize", nil])
        #expect(segments[1].url?.still?.absoluteString == "https://files.kick.com/emotes/37226/fullsize")
    }

    @Test
    func emoteAtStartAndEnd() {
        let segments = createSegments("[emote:1:A] hi [emote:2:B]")
        #expect(texts(segments) == [nil, "hi ", nil])
        #expect(segments.compactMap { $0.url?.still?.absoluteString } == [
            "https://files.kick.com/emotes/1/fullsize",
            "https://files.kick.com/emotes/2/fullsize",
        ])
    }

    @Test
    func consecutiveEmotes() {
        let segments = createSegments("[emote:1:A][emote:2:B]")
        #expect(texts(segments) == [nil, nil])
        #expect(segments.count == 2)
    }

    @Test
    func onlyEmote() {
        let segments = createSegments("[emote:1:A]")
        #expect(texts(segments) == [nil])
    }

    @Test
    func malformedEmoteIsPlainText() {
        let segments = createSegments("[emote:abc:A] hi")
        #expect(texts(segments) == ["[emote:abc:A] ", "hi "])
        #expect(emoteNames(segments) == [nil, nil])
    }

    @Test
    func thirdPartyEmotesAroundKickEmote() {
        let segments = createSegments("LUL [emote:1:A] LUL", emotes: ["LUL"])
        #expect(texts(segments) == ["", "", nil, "", ""])
        #expect(emoteNames(segments) == ["LUL", nil, "fullsize", "LUL", nil])
    }

    @Test
    func idsAreUnique() {
        let segments = createSegments("a [emote:1:A] b LUL c", emotes: ["LUL"])
        #expect(Set(segments.map(\.id)).count == segments.count)
    }
}
