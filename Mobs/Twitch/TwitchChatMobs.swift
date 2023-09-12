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
    private var connected: Bool = false

    init(model: Model) {
        self.model = model
    }
    
    func isConnected() -> Bool {
        return connected
    }

    func start(channelName: String) {
        self.channelName = channelName
        task = Task.init {
            var reconnectTime: UInt64 = 0
            logger.info("twitch: chat: \(channelName): Connecting")
            while true {
                twitchChat = TwitchChat(token: "SCHMOOPIIE", nick: "justinfan67420", name: channelName)
                do {
                    connected = true
                    for try await message in self.twitchChat!.messages {
                        reconnectTime = 0
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
                    logger.warning("twitch: chat: \(channelName): Got error \(error)")
                }
                connected = false
                logger.info("twitch: chat: \(channelName): Disconnected")
                try await Task.sleep(nanoseconds: reconnectTime)
                reconnectTime += 500_000_000
                reconnectTime = min(reconnectTime, 20_000_000_000)
                logger.info("twitch: chat: \(channelName): Reconnecting")
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        twitchChat = nil
    }
}
