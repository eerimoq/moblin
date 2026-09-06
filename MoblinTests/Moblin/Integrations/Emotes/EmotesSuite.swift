import Foundation
@testable import Moblin
import Testing

struct EmotesSuite {
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
