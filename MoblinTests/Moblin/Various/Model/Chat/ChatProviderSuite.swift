@testable import Moblin
import Testing

@MainActor
struct ChatProviderSuite {
    private func makePost(id: Int) -> ChatPost {
        ChatPost(
            id: id,
            messageId: nil,
            displayName: "user",
            user: "user",
            userColor: .init(red: 0, green: 0, blue: 0),
            userBadges: [],
            segments: [],
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

    @Test
    func newestPostFirst() {
        let chat = ChatProvider()
        for id in 0 ..< 3 {
            chat.appendMessage(post: makePost(id: id))
        }
        chat.update()
        #expect(chat.posts.map(\.id) == [2, 1, 0])
    }

    @Test
    func dropsOldestWhenFull() {
        let chat = ChatProvider()
        for id in 0 ..< maximumNumberOfChatMessages + 10 {
            chat.appendMessage(post: makePost(id: id))
        }
        chat.update()
        #expect(chat.posts.count == maximumNumberOfChatMessages)
        #expect(chat.posts.first?.id == maximumNumberOfChatMessages + 9)
        #expect(chat.posts.last?.id == 10)
    }

    @Test
    func pausedKeepsPostsUntilEndReached() {
        let chat = ChatProvider()
        chat.appendMessage(post: makePost(id: 0))
        chat.update()
        chat.pause()
        chat.appendMessage(post: makePost(id: 1))
        chat.appendMessage(post: makePost(id: 2))
        chat.update()
        #expect(chat.paused)
        #expect(chat.pausedPostsCount == 2)
        #expect(chat.posts.map(\.id) == [0])
        chat.endReachedWhenPaused()
        #expect(!chat.paused)
        #expect(chat.posts.map(\.id) == [2, 1, 0])
    }

    @Test
    func pausedDropsOldestWhenFull() {
        let chat = ChatProvider()
        chat.pause()
        let count = 2 * maximumNumberOfChatMessages + 10
        for id in 0 ..< count {
            chat.appendMessage(post: makePost(id: id))
        }
        chat.update()
        #expect(chat.pausedPostsCount == 2 * maximumNumberOfChatMessages)
        chat.endReachedWhenPaused()
        #expect(chat.posts.count == maximumNumberOfChatMessages)
        #expect(chat.posts.first?.id == count - 1)
        #expect(chat.posts.last?.id == count - maximumNumberOfChatMessages)
    }
}
