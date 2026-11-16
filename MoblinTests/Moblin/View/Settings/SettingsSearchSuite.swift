@testable import Moblin
import Testing

struct SettingsSearchSuite {
    struct MatchCase: CustomTestStringConvertible {
        let testDescription: String
        let text: String

        init(_ description: String, _ text: String) {
            testDescription = description
            self.text = text
        }
    }

    @Test(arguments: [
        MatchCase("title", "Video"),
        MatchCase("title prefix", "vid"),
        MatchCase("keyword", "fps"),
        MatchCase("breadcrumb", "stre"),
        MatchCase("case insensitive", "BITRATE"),
        MatchCase("diacritic insensitive", "résolution"),
        MatchCase("all words match", "video  hevc"),
        MatchCase("words across title and path", "streams bitrate"),
        MatchCase("any word order", "hevc video"),
    ])
    func matches(testCase: MatchCase) {
        #expect(settingsSearchMatches(text: testCase.text,
                                      title: "Video",
                                      path: ["Streams"],
                                      keywords: ["Bitrate", "Resolution", "FPS", "hevc"]))
    }

    @Test(arguments: [
        MatchCase("empty", ""),
        MatchCase("whitespace", "   "),
        MatchCase("unknown word", "vibrate"),
        MatchCase("one of two words missing", "video vibrate"),
        MatchCase("middle of word", "ideo"),
        MatchCase("end of word", "rate"),
    ])
    func doesNotMatch(testCase: MatchCase) {
        #expect(!settingsSearchMatches(text: testCase.text,
                                       title: "Video",
                                       path: ["Streams"],
                                       keywords: ["Bitrate", "Resolution", "FPS", "hevc"]))
    }
}
