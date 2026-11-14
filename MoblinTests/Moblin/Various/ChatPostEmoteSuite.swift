import Foundation
@testable import Moblin
import Testing

struct ChatPostEmoteSuite {
    private let moving = URL(string: "https://emotes.example.com/moving.gif")!
    private let still = URL(string: "https://emotes.example.com/still.png")!

    @Test
    func prefersMovingWhenAnimated() {
        let emote = ChatPostEmote(moving: moving, still: still)
        #expect(emote.url(animated: true) == moving)
        #expect(emote.url(animated: false) == still)
    }

    @Test
    func fallsBackToTheOtherOne() {
        #expect(ChatPostEmote(moving: nil, still: still).url(animated: true) == still)
        #expect(ChatPostEmote(moving: moving, still: nil).url(animated: false) == moving)
        #expect(ChatPostEmote(moving: nil, still: nil).url(animated: true) == nil)
    }
}
