import Foundation
import TwitchChat

final class TwitchChatMobs {
    private var twitchChat: TwitchChat?
    private var channelName: String
    private var model: Model
    private var messages: [String] = []

    init(channelName: String, model: Model){
        self.channelName = channelName
        self.model = model
    }

    func start() {
        twitchChat = TwitchChat(token: "SCHMOOPIIE", nick: "justinfan67420", name: channelName)
        Task.detached {
            for try await message in self.twitchChat!.messages {
                await MainActor.run {
                    if self.messages.count > 5 {
                        self.messages.removeFirst()
                    }
                    self.messages.append("\(message.sender.prefix(5)): \(message.text.prefix(40))")
                    self.model.chatText = self.messages.joined(separator: "\n")
                }
            }
        }
    }
}
