import Collections
import Foundation

@MainActor
class ChatProvider: ObservableObject {
    var newPosts: Deque<ChatPost> = []
    var pausedPosts: Deque<ChatPost> = []
    @Published var posts: Deque<ChatPost> = []
    @Published var pausedPostsCount: Int = 0
    @Published var paused = false
    @Published var moreThanOneStreamingPlatform = false
    @Published var interactiveChat = false
    @Published var triggerScrollToBottom = false
    @Published var showLabel = false
    private let hideLabelTimer = MainTimer()

    func showLabelForAWhile() {
        showLabel = true
        hideLabelTimer.startSingleShot(timeout: 5) { [weak self] in
            self?.showLabel = false
        }
    }

    func appendMessage(post: ChatPost) {
        if paused {
            if pausedPosts.count > 2 * maximumNumberOfChatMessages - 1 {
                pausedPosts.removeFirst()
            }
            pausedPosts.append(post)
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
            if pausedPosts.count != pausedPostsCount {
                pausedPostsCount = pausedPosts.count
            }
        } else {
            while let post = newPosts.popFirst() {
                if posts.count > maximumNumberOfChatMessages - 1 {
                    posts.removeLast()
                }
                posts.prepend(post)
            }
        }
    }

    func pause() {
        paused = true
        pausedPostsCount = 0
        pausedPosts = []
        while let post = newPosts.popFirst() {
            appendMessage(post: post)
        }
    }

    func endReachedWhenPaused() {
        while let post = pausedPosts.popFirst() {
            if posts.count > maximumNumberOfChatMessages - 1 {
                posts.removeLast()
            }
            posts.prepend(post)
        }
        paused = false
    }
}
