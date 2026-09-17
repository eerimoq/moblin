import Foundation
@testable import Moblin
import Testing

private func makeTwitchEmote(_ name: String, _ range: ClosedRange<Int>) -> ChatMessageEmote {
    ChatMessageEmote(url: URL(string: "https://twitch.example.com/\(name)")!,
                     stillUrl: URL(string: "https://twitch.example.com/still/\(name)")!,
                     range: range)
}

private func makeTwitchGif(_ name: String, _ range: ClosedRange<Int>) -> ChatMessageEmote {
    ChatMessageEmote(url: URL(string: "https://giphy.example.com/\(name)")!, range: range, isGif: true)
}

private func gifNames(_ segments: [ChatPostSegment]) -> [String?] {
    segments.map { $0.bigGifUrl?.moving?.lastPathComponent }
}

private func textFragment(_ text: String) -> TwitchEventSubMessageFragment {
    TwitchEventSubMessageFragment(type: "text", text: text, emote: nil)
}

private func emoteFragment(_ text: String, id: String) -> TwitchEventSubMessageFragment {
    TwitchEventSubMessageFragment(type: "emote", text: text, emote: .init(id: id))
}

private func twitchEmoteIds(_ segments: [ChatPostSegment]) -> [String?] {
    segments.map { segment in
        guard let path = segment.url?.still?.path else {
            return nil
        }
        return path.split(separator: "/").dropFirst(2).first.map(String.init)
    }
}

struct TwitchChatSegmentsSuite {
    private func createSegments(_ text: String,
                                _ emotes: [ChatMessageEmote],
                                thirdParty: [String] = []) -> [ChatPostSegment]
    {
        var id = 0
        return createTwitchSegments(text: text,
                                    emotes: emotes,
                                    emotesManager: makeEmotes(thirdParty),
                                    id: &id)
    }

    private func createSegments(_ fragments: [TwitchEventSubMessageFragment],
                                thirdParty: [String] = []) -> [ChatPostSegment]
    {
        var id = 0
        return createTwitchSegments(fragments: fragments, emotesManager: makeEmotes(thirdParty), id: &id)
    }

    @Test
    func fragmentsWithoutEmotes() {
        let segments = createSegments([textFragment("hello world")])
        #expect(texts(segments) == ["hello ", "world "])
        #expect(twitchEmoteIds(segments) == [nil, nil])
    }

    @Test
    func fragmentsWithEmoteInTheMiddle() {
        let segments = createSegments([
            textFragment("hi "),
            emoteFragment("Kappa", id: "25"),
            textFragment(" lol"),
        ])
        #expect(texts(segments) == ["hi ", nil, "", "lol "])
        #expect(twitchEmoteIds(segments) == [nil, "25", nil, nil])
    }

    @Test
    func fragmentsWithAdjacentEmotes() {
        let segments = createSegments([
            emoteFragment("Kappa", id: "25"),
            textFragment(" "),
            emoteFragment("PogChamp", id: "305954156"),
        ])
        #expect(texts(segments) == [nil, "", nil, ""])
        #expect(twitchEmoteIds(segments) == ["25", nil, "305954156", nil])
    }

    @Test
    func fragmentsWithThirdPartyEmoteInText() {
        let segments = createSegments([textFragment("LUL "), emoteFragment("Kappa", id: "25")],
                                      thirdParty: ["LUL"])
        #expect(texts(segments) == ["", "", nil, ""])
        #expect(emoteNames(segments).first == "LUL")
        #expect(twitchEmoteIds(segments)[2] == "25")
    }

    @Test
    func fragmentsWithMentionAndCheermoteAreText() {
        let segments = createSegments([
            TwitchEventSubMessageFragment(type: "mention", text: "@Viewer", emote: nil),
            textFragment(" "),
            TwitchEventSubMessageFragment(type: "cheermote", text: "Cheer100", emote: nil),
        ])
        #expect(texts(segments) == ["@Viewer ", "Cheer100 "])
        #expect(twitchEmoteIds(segments) == [nil, nil])
    }

    @Test
    func fragmentIdsAreUnique() {
        let segments = createSegments([
            textFragment("a "),
            emoteFragment("Kappa", id: "25"),
            textFragment(" LUL b"),
        ], thirdParty: ["LUL"])
        #expect(Set(segments.map(\.id)).count == segments.count)
    }

    @Test
    func noEmotes() {
        let segments = createSegments("hello world", [])
        #expect(texts(segments) == ["hello ", "world "])
        #expect(emoteNames(segments) == [nil, nil])
    }

    @Test
    func emoteInTheMiddle() {
        let segments = createSegments("hi Kappa lol", [makeTwitchEmote("Kappa", 3 ... 7)])
        #expect(texts(segments) == ["hi ", nil, "", "lol "])
        #expect(emoteNames(segments) == [nil, "Kappa", nil, nil])
    }

    @Test
    func emoteAtStart() {
        let segments = createSegments("Kappa lol", [makeTwitchEmote("Kappa", 0 ... 4)])
        #expect(texts(segments) == [nil, "", "lol "])
        #expect(emoteNames(segments) == ["Kappa", nil, nil])
    }

    @Test
    func emoteAtEnd() {
        let segments = createSegments("lol Kappa", [makeTwitchEmote("Kappa", 4 ... 8)])
        #expect(texts(segments) == ["lol ", nil, ""])
        #expect(emoteNames(segments) == [nil, "Kappa", nil])
    }

    @Test
    func onlyEmote() {
        let segments = createSegments("Kappa", [makeTwitchEmote("Kappa", 0 ... 4)])
        #expect(texts(segments) == [nil, ""])
        #expect(emoteNames(segments) == ["Kappa", nil])
    }

    @Test
    func adjacentEmotes() {
        let segments = createSegments("KappaLUL", [
            makeTwitchEmote("Kappa", 0 ... 4),
            makeTwitchEmote("LUL", 5 ... 7),
        ])
        #expect(texts(segments) == [nil, "", nil, ""])
        #expect(emoteNames(segments) == ["Kappa", nil, "LUL", nil])
    }

    @Test
    func unsortedEmotes() {
        let segments = createSegments("Kappa a LUL", [
            makeTwitchEmote("LUL", 8 ... 10),
            makeTwitchEmote("Kappa", 0 ... 4),
        ])
        #expect(texts(segments) == [nil, "", "a ", nil, ""])
        #expect(emoteNames(segments) == ["Kappa", nil, nil, "LUL", nil])
    }

    @Test
    func emoteRangeOutsideText() {
        let segments = createSegments("hi", [makeTwitchEmote("Kappa", 3 ... 7)])
        #expect(texts(segments) == ["hi "])
        #expect(emoteNames(segments) == [nil])
    }

    @Test
    func rangesAreCountedInUnicodeScalars() {
        let segments = createSegments("😀 Kappa", [makeTwitchEmote("Kappa", 2 ... 6)])
        #expect(texts(segments) == ["😀 ", nil, ""])
        #expect(emoteNames(segments) == [nil, "Kappa", nil])
    }

    @Test
    func onlyGif() {
        let segments = createSegments("[Hello GIF by HULU]", [makeTwitchGif("hello", 0 ... 18)])
        #expect(texts(segments) == [nil, ""])
        #expect(emoteNames(segments) == [nil, nil])
        #expect(gifNames(segments) == ["hello", nil])
        #expect(segments.compactMap(\.text).joined().isEmpty)
    }

    @Test
    func gifAfterEmote() {
        let segments = createSegments("Kappa [gif]", [
            makeTwitchGif("hello", 6 ... 10),
            makeTwitchEmote("Kappa", 0 ... 4),
        ])
        #expect(texts(segments) == [nil, "", nil, ""])
        #expect(emoteNames(segments) == ["Kappa", nil, nil, nil])
        #expect(gifNames(segments) == [nil, nil, "hello", nil])
    }

    @Test
    func thirdPartyEmotesAroundTwitchEmote() {
        let segments = createSegments("LUL Kappa LUL",
                                      [makeTwitchEmote("Kappa", 4 ... 8)],
                                      thirdParty: ["LUL"])
        #expect(texts(segments) == ["", "", nil, "", "", ""])
        #expect(emoteNames(segments) == ["LUL", nil, "Kappa", nil, "LUL", nil])
    }

    @Test
    func idsAreUnique() {
        let segments = createSegments("a Kappa b LUL c",
                                      [makeTwitchEmote("Kappa", 2 ... 6)],
                                      thirdParty: ["LUL"])
        #expect(Set(segments.map(\.id)).count == segments.count)
    }

    @Test
    func rangeInsideWordKeepsSurroundingCharacters() {
        let segments = createSegments("hello", [makeTwitchEmote("Kappa", 1 ... 3)])
        #expect(texts(segments) == ["h ", nil, "", "o "])
        #expect(emoteNames(segments) == [nil, "Kappa", nil, nil])
    }

    @Test
    func overlappingRangesKeepTheFirstEmote() {
        let segments = createSegments("aa Kappa bb", [
            makeTwitchEmote("Kappa", 3 ... 7),
            makeTwitchEmote("Overlapping", 5 ... 9),
        ])
        #expect(texts(segments) == ["aa ", nil, "", "bb "])
        #expect(emoteNames(segments) == [nil, "Kappa", nil, nil])
    }
}
