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
    private var channelName: String? = nil

    init(model: Model) {
        self.model = model
    }

    func start(channelName: String) {
        self.channelName = channelName
        logger.info("twitch-chat: Starting channel \(channelName).")
        task = Task.init {
            var reconnectTime: UInt64 = 2
            logger.info("twitch-chat: Connecting to channel \(channelName).")
            while true {
                twitchChat = TwitchChat(token: "SCHMOOPIIE", nick: "justinfan67420", name: channelName)
                do {
                    for try await message in self.twitchChat!.messages {
                        reconnectTime = 2
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
                } catch {
                    logger.warning("twitch-chat: Got error \(error) for channel \(channelName)")
                }
                logger.info("twitch-chat: Disconnected from channel \(channelName).")
                try await Task.sleep(nanoseconds: reconnectTime)
                reconnectTime += 2
                reconnectTime = min(reconnectTime, 20)
                logger.info("twitch-chat: Reconnecting to channel \(channelName).")
            }
        }
    }

    func stop() {
        logger.info("twitch-chat: Stopping channel \(self.channelName ?? "").")
        task?.cancel()
        task = nil
        twitchChat = nil
    }
}
