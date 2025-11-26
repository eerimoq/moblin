import Collections
import Foundation

class ChatProvider: ObservableObject {
    var newPosts: Deque<ChatPost> = []
    var pausedPosts: Deque<ChatPost> = []
    @Published var posts: Deque<ChatPost> = []
    @Published var pausedPostsCount: Int = 0
    @Published var paused = false
    private let maximumNumberOfMessages: Int
    @Published var moreThanOneStreamingPlatform = false
    @Published var interactiveChat = false
    @Published var triggerScrollToBottom = false

    init(maximumNumberOfMessages: Int) {
        self.maximumNumberOfMessages = maximumNumberOfMessages
    }

    func reset() {
        posts = []
        pausedPosts = []
        newPosts = []
    }

    func appendMessage(post: ChatPost) {
        if paused {
            if pausedPosts.count < 2 * maximumNumberOfMessages {
                pausedPosts.append(post)
            }
        } else {
            newPosts.append(post)
        }
    }

    func deleteMessage(messageId: String) {
        for post in newPosts where post.messageId == messageId {
            post.state.deleted = true
        }
        for post in pausedPosts where post.messageId == messageId {
            post.state.deleted = true
        }
        for post in posts where post.messageId == messageId {
            post.state.deleted = true
        }
    }

    func deleteUser(userId: String) {
        for post in newPosts where post.userId == userId {
            post.state.deleted = true
        }
        for post in pausedPosts where post.userId == userId {
            post.state.deleted = true
        }
        for post in posts where post.userId == userId {
            post.state.deleted = true
        }
    }

    func update() {
        if paused {
            let count = max(pausedPosts.count - 1, 0)
            if count != pausedPostsCount {
                pausedPostsCount = count
            }
        } else {
            while let post = newPosts.popFirst() {
                if posts.count > maximumNumberOfMessages - 1 {
                    posts.removeLast()
                }
                posts.prepend(post)
            }
        }
    }
}
