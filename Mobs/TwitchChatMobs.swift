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
    private var id: Int = 0
    private var stopped = false

    init(channelName: String, model: Model){
        self.channelName = channelName
        self.model = model
    }
    
    func start() {
        print("Starting twitch chat.")
        twitchChat = TwitchChat(token: "SCHMOOPIIE", nick: "justinfan67420", name: channelName)
        Task.detached {
            for try await message in self.twitchChat!.messages {
                if self.stopped {
                    print("Discarding twitch chat message as stopped.")
                    continue
                }
                await MainActor.run {
                    if self.stopped {
                        return
                    }
                    self.id += 1
                    if self.model.twitchChatPosts.count > 6 {
                        self.model.twitchChatPosts.removeFirst()
                    }
                    self.model.twitchChatPosts.append(Post(id: self.id, user: message.sender, message: message.text))
                    self.model.numberOfTwitchChatPosts += 1
                }
            }
        }
    }
    
    func stop() {
        print("Stopping twitch chat.")
        stopped = true
    }
}
