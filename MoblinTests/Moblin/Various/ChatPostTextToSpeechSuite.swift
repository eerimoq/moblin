import Foundation
@testable import Moblin
import Testing

struct ChatPostTextToSpeechSuite {
    private func makePost(segments: [ChatPostSegment]) -> ChatPost {
        ChatPost(
            id: 0,
            messageId: nil,
            displayName: "user",
            user: "user",
            userColor: .init(red: 0, green: 0, blue: 0),
            userBadges: [],
            segments: segments,
            timestamp: "",
            timestampTime: .now,
            isAction: false,
            isSubscriber: false,
            bits: nil,
            highlight: nil,
            live: true,
            filter: nil,
            platform: nil,
            sourceChannelIcon: nil,
            state: ChatPostState()
        )
    }

    private func makeEmote(_ name: String?) -> ChatPostEmote {
        let url = URL(string: "https://emotes.example.com/emote")!
        return ChatPostEmote(moving: url, still: url, name: name)
    }

    private func makeTwitchPost() -> ChatPost {
        let kappa = ChatMessageEmote(url: URL(string: "https://twitch.example.com/Kappa")!, range: 3 ... 7)
        var id = 0
        let segments = createTwitchSegments(text: "hi Kappa LUL lol",
                                            emotes: [kappa],
                                            emotesManager: makeEmotes(["LUL"]),
                                            id: &id)
        return makePost(segments: segments)
    }

    @Test
    func emotesAreSkippedWhenNotSayingEmotes() {
        let post = makeTwitchPost()
        #expect(post.textToSpeechText(sayEmotes: false) == "hi lol")
        #expect(post.textToSpeechText(sayEmotes: false) == post.text())
    }

    @Test
    func emoteNamesAreSaidWhenSayingEmotes() {
        let post = makeTwitchPost()
        #expect(post.textToSpeechText(sayEmotes: true) == "hi Kappa LUL lol")
    }

    @Test
    func onlyEmotes() {
        var id = 0
        let segments = createKickSegments(message: "[emote:1:KEKW][emote:2:PogU]",
                                          emotesManager: makeEmotes([]),
                                          id: &id)
        let post = makePost(segments: segments)
        #expect(post.textToSpeechText(sayEmotes: false) == "")
        #expect(post.textToSpeechText(sayEmotes: true) == "KEKW PogU")
    }

    @Test
    func bigGifNameIsSaid() {
        let post = makePost(segments: [
            ChatPostSegment(id: 0, text: "look "),
            ChatPostSegment(id: 1, bigGifUrl: makeEmote("Hello GIF")),
        ])
        #expect(post.textToSpeechText(sayEmotes: true) == "look Hello GIF")
    }

    @Test
    func emoteWithoutNameIsSkipped() {
        let post = makePost(segments: [
            ChatPostSegment(id: 0, text: "hi "),
            ChatPostSegment(id: 1, url: makeEmote(nil)),
            ChatPostSegment(id: 2, text: "there "),
        ])
        #expect(post.textToSpeechText(sayEmotes: true) == "hi there")
    }
}
