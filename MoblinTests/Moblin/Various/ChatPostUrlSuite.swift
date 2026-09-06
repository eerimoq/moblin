import Foundation
@testable import Moblin
import Testing

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
