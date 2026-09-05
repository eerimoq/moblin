import Foundation
@testable import Moblin
import Testing

private func makeEmotes(_ names: [String]) -> Emotes {
    let emotes = Emotes()
    var byName: [String: Emote] = [:]
    for name in names {
        byName[name] = Emote(url: URL(string: "https://emotes.example.com/\(name)")!)
    }
    emotes.addEmotes(byName)
    return emotes
}

private func makeTwitchEmote(_ name: String, _ range: ClosedRange<Int>) -> ChatMessageEmote {
    ChatMessageEmote(url: URL(string: "https://twitch.example.com/\(name)")!,
                     stillUrl: URL(string: "https://twitch.example.com/still/\(name)")!,
                     range: range)
}

private func texts(_ segments: [ChatPostSegment]) -> [String?] {
    segments.map(\.text)
}

private func makeTwitchGif(_ name: String, _ range: ClosedRange<Int>) -> ChatMessageEmote {
    ChatMessageEmote(url: URL(string: "https://giphy.example.com/\(name)")!, range: range, isGif: true)
}

private func emoteNames(_ segments: [ChatPostSegment]) -> [String?] {
    segments.map { $0.url?.still?.lastPathComponent }
}

private func gifNames(_ segments: [ChatPostSegment]) -> [String?] {
    segments.map { $0.gifUrl?.moving?.lastPathComponent }
}

struct ChatSegmentsSuite {
    private func createSegments(_ text: String, emotes: [String] = []) -> [ChatPostSegment] {
        var id = 0
        return makeEmotes(emotes).createSegments(text: text, id: &id)
    }

    @Test
    func plainText() {
        let segments = createSegments("hello world")
        #expect(texts(segments) == ["hello ", "world "])
        #expect(emoteNames(segments) == [nil, nil])
    }

    @Test
    func emptyText() {
        #expect(createSegments("").isEmpty)
    }

    @Test
    func whitespaceOnlyText() {
        #expect(createSegments("   ").isEmpty)
    }

    @Test
    func surroundingAndRepeatedWhitespaceIsCollapsed() {
        let segments = createSegments("  hello   world  ")
        #expect(texts(segments) == ["hello ", "world "])
    }

    @Test
    func newlinesSeparateWords() {
        let segments = createSegments("hello\nworld")
        #expect(texts(segments) == ["hello ", "world "])
    }

    @Test
    func emoteInTheMiddle() {
        let segments = createSegments("hello Kappa world", emotes: ["Kappa"])
        #expect(texts(segments) == ["hello ", "", "", "world "])
        #expect(emoteNames(segments) == [nil, "Kappa", nil, nil])
    }

    @Test
    func emoteFirstAndLast() {
        let segments = createSegments("Kappa hi LUL", emotes: ["Kappa", "LUL"])
        #expect(texts(segments) == ["", "", "hi ", "", ""])
        #expect(emoteNames(segments) == ["Kappa", nil, nil, "LUL", nil])
    }

    @Test
    func consecutiveEmotes() {
        let segments = createSegments("Kappa LUL", emotes: ["Kappa", "LUL"])
        #expect(emoteNames(segments) == ["Kappa", nil, "LUL", nil])
    }

    @Test
    func emoteLookupIsCaseSensitive() {
        let segments = createSegments("kappa", emotes: ["Kappa"])
        #expect(texts(segments) == ["kappa "])
        #expect(emoteNames(segments) == [nil])
    }

    @Test
    func emoteMustBeAWholeWord() {
        let segments = createSegments("xKappa Kappa!", emotes: ["Kappa"])
        #expect(texts(segments) == ["xKappa ", "Kappa! "])
        #expect(emoteNames(segments) == [nil, nil])
    }

    @Test
    func idsAreUnique() {
        let segments = createSegments("a Kappa b LUL c", emotes: ["Kappa", "LUL"])
        #expect(Set(segments.map(\.id)).count == segments.count)
    }

    @Test
    func idsContinueFromCaller() {
        var id = 7
        let segments = makeEmotes([]).createSegments(text: "a b", id: &id)
        #expect(segments.map(\.id) == [7, 8])
        #expect(id == 9)
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

struct CheermotesSuite {
    private func makeCheermotes(_ prefixes: [String: [Int]]) -> Cheermotes {
        let cheermotes = Cheermotes()
        cheermotes.addCheermotes(datas: prefixes.map { prefix, minBits in
            TwitchApiGetCheermotesData(prefix: prefix, tiers: minBits.map { minBits in
                TwitchApiGetCheermotesDataTier(
                    min_bits: minBits,
                    images: TwitchApiGetCheermotesDataTiersImages(
                        dark: TwitchApiGetCheermotesDataTiersImagesTheme(
                            static_: TwitchApiGetCheermotesDataTiersImagesThemeKind(
                                two: "https://cheer.example.com/\(prefix)/\(minBits)"
                            )
                        )
                    )
                )
            })
        })
        return cheermotes
    }

    @Test
    func matchesPrefixAndBits() throws {
        let cheermotes = makeCheermotes(["cheer": [1]])
        let (url, bits) = try #require(cheermotes.getUrlAndBits(word: "cheer100"))
        #expect(url.absoluteString == "https://cheer.example.com/cheer/1")
        #expect(bits == 100)
    }

    @Test
    func ignoresSurroundingWhitespaceAndCase() throws {
        let cheermotes = makeCheermotes(["cheer": [1]])
        let (_, bits) = try #require(cheermotes.getUrlAndBits(word: " Cheer250 "))
        #expect(bits == 250)
    }

    @Test
    func picksHighestMatchingTier() throws {
        let cheermotes = makeCheermotes(["cheer": [1, 100, 1000, 5000]])
        #expect(try #require(cheermotes.getUrlAndBits(word: "cheer1")).0.lastPathComponent == "1")
        #expect(try #require(cheermotes.getUrlAndBits(word: "cheer500")).0.lastPathComponent == "100")
        #expect(try #require(cheermotes.getUrlAndBits(word: "cheer1000")).0.lastPathComponent == "1000")
        #expect(try #require(cheermotes.getUrlAndBits(word: "cheer99999")).0.lastPathComponent == "5000")
    }

    @Test
    func belowLowestTierDoesNotMatch() {
        let cheermotes = makeCheermotes(["cheer": [100]])
        #expect(cheermotes.getUrlAndBits(word: "cheer1") == nil)
    }

    @Test
    func prefixEndingInDigitPrefersTheLongestPrefix() throws {
        let cheermotes = makeCheermotes(["cheer": [1], "cheer1": [1]])
        let (url, bits) = try #require(cheermotes.getUrlAndBits(word: "cheer1100"))
        #expect(url.absoluteString == "https://cheer.example.com/cheer1/1")
        #expect(bits == 100)
    }

    @Test
    func withoutBitsDoesNotMatch() {
        let cheermotes = makeCheermotes(["cheer": [1]])
        #expect(cheermotes.getUrlAndBits(word: "cheer") == nil)
    }

    @Test
    func unknownPrefixDoesNotMatch() {
        let cheermotes = makeCheermotes(["cheer": [1]])
        #expect(cheermotes.getUrlAndBits(word: "notacheermote100") == nil)
    }

    @Test
    func partialWordDoesNotMatch() {
        let cheermotes = makeCheermotes(["cheer": [1]])
        #expect(cheermotes.getUrlAndBits(word: "xcheer100") == nil)
        #expect(cheermotes.getUrlAndBits(word: "cheer100x") == nil)
    }

    @Test
    func emptyWordDoesNotMatch() {
        let cheermotes = makeCheermotes(["cheer": [1]])
        #expect(cheermotes.getUrlAndBits(word: "") == nil)
        #expect(cheermotes.getUrlAndBits(word: "100") == nil)
    }

    @Test
    func noCheermotesFetched() {
        #expect(Cheermotes().getUrlAndBits(word: "cheer100") == nil)
    }
}

struct ChatPostUrlSuite {
    private let moving = URL(string: "https://emotes.example.com/moving.gif")!
    private let still = URL(string: "https://emotes.example.com/still.png")!

    @Test
    func prefersMovingWhenAnimated() {
        let url = ChatPostUrl(moving: moving, still: still)
        #expect(url.url(animated: true) == moving)
        #expect(url.url(animated: false) == still)
    }

    @Test
    func fallsBackToTheOtherOne() {
        #expect(ChatPostUrl(moving: nil, still: still).url(animated: true) == still)
        #expect(ChatPostUrl(moving: moving, still: nil).url(animated: false) == moving)
        #expect(ChatPostUrl(moving: nil, still: nil).url(animated: true) == nil)
    }
}
