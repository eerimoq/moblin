import Collections

struct ChatBotMessage {
    let platform: Platform
    let user: String?
    let isModerator: Bool
    let isSubscriber: Bool
    let userId: String?
    let segments: [ChatPostSegment]
}

class ChatBotCommand {
    let message: ChatBotMessage
    private var parts: Deque<String> = []

    init?(message: ChatBotMessage, aliases: [SettingsChatBotAlias]) {
        self.message = message
        guard let firstWord = message.segments.first?.text?.lowercased().trim() else {
            return nil
        }
        if firstWord != "!moblin" {
            guard let alias = aliases.first(where: { $0.alias == firstWord }) else {
                return nil
            }
            for word in alias.replacement.split(separator: " ").suffix(from: 1) {
                parts.append(word.trim())
            }
        }
        if message.segments.count > 1 {
            for segment in message.segments.suffix(from: 1) {
                if let text = segment.text {
                    parts.append(text.trim())
                }
            }
        }
    }

    func popFirst() -> String? {
        return parts.popFirst()
    }

    func peekFirst() -> String? {
        return parts.first
    }

    func rest() -> String {
        return parts.joined(separator: " ")
    }

    func user() -> String? {
        return message.user
    }
}
