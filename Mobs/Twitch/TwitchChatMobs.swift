import Foundation
import TwitchChat

struct Post: Hashable {
    var id: Int
    var user: String
    var message: String
}

final class TwitchChatMobs {
    private var twitchChat: TwitchChat?
    private var model: Model
    private var task: Task<Void, Error>? = nil
    private var id = 0

    init(model: Model) {
        self.model = model
    }

    func start(channelName: String) {
        twitchChat = TwitchChat(token: "SCHMOOPIIE", nick: "justinfan67420", name: channelName)
        task = Task.init {
            for try await message in self.twitchChat!.messages {
                await MainActor.run {
                    if self.model.twitchChatPosts.count > 6 {
                        self.model.twitchChatPosts.removeFirst()
                    }
                    let post = Post(id: self.id, user: message.sender, message: message.text)
                    self.model.twitchChatPosts.append(post)
                    self.model.numberOfTwitchChatPosts += 1
                    self.id += 1
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
