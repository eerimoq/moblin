import Foundation
@testable import Moblin
import Testing

@MainActor
struct ChatEmoteComboEffectSuite {
    @Test
    func resetTimerDoesNotRetainEffect() throws {
        let url = try #require(URL(string: "https://emotes.example.com/emote.png"))
        let emote = ChatPostEmote(moving: nil, still: url)
        let post = ChatPost(
            id: 0,
            messageId: nil,
            displayName: "user",
            user: "user",
            userColor: .init(red: 0, green: 0, blue: 0),
            userBadges: [],
            segments: [ChatPostSegment(id: 0, url: emote)],
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
        var effect: ChatEmoteComboEffect? = ChatEmoteComboEffect(canvasSize: .init(width: 1920, height: 1080))
        weak var weakEffect = effect
        effect?.appendMessage(post: post)
        effect = nil
        #expect(weakEffect == nil)
    }
}
