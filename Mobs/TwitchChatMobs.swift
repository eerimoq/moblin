import Foundation
import TwitchChat

struct Post: Hashable {
    var user: String
    var message: String
}

final class TwitchChatMobs {
    private var twitchChat: TwitchChat?
    private var channelName: String
    private var model: Model
    private var posts: [Post] = []

    init(channelName: String, model: Model){
        self.channelName = channelName
        self.model = model
    }

    func start() {
        twitchChat = TwitchChat(token: "SCHMOOPIIE", nick: "justinfan67420", name: channelName)
        Task.detached {
            for try await message in self.twitchChat!.messages {
                await MainActor.run {
                    if self.posts.count > 6 {
                        self.posts.removeFirst()
                    }
                    self.posts.append(Post(user: message.sender, message: message.text))
                    self.model.twitchChatPosts = self.posts
                }
            }
        }
    }
}
