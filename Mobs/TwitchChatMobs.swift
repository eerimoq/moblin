import Foundation
import TwitchChat

public final class TwitchChatMobs {
    private var twitchChat: TwitchChat?
    private var channelName: String

    public init(channelName: String){
        self.channelName = channelName
    }

    public func start() {
        twitchChat = TwitchChat(token: "SCHMOOPIIE", nick: "justinfan67420", name: channelName)
        Task.detached {
            for try await message in self.twitchChat!.messages {
                print(self.channelName, "'s chat: ", message.text, separator: "")
            }
        }
    }
}
