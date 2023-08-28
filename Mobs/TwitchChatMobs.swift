import Foundation
import TwitchChat

struct Post: Hashable {
    var id: Int
    var user: String
    var message: String
}

final class TwitchChatMobs {
    private var twitchChat: TwitchChat?
    private var channelName: String
    private var model: Model
    private var posts: [Post] = []
    private var id: Int = 0

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
                    self.id += 1
                    self.posts.append(Post(id: self.id, user: message.sender, message: message.text))
                    self.model.twitchChatPosts = self.posts
                }
            }
        }
    }
}
