import Foundation
import TwitchChat

final class TwitchChatMobs {
    private var twitchChat: TwitchChat?
    private var channelName: String
    private var model: Model

    init(channelName: String, model: Model){
        self.channelName = channelName
        self.model = model
    }

    func start() {
        twitchChat = TwitchChat(token: "SCHMOOPIIE", nick: "justinfan67420", name: channelName)
        Task.detached {
            for try await message in self.twitchChat!.messages {
                await MainActor.run {
                    self.model.chatText = "\(message.sender): \(message.text)"
                }
            }
        }
    }
}
