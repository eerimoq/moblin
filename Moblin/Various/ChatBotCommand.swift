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

    init?(message: ChatBotMessage) {
        self.message = message
        guard message.segments.count > 1 else {
            return nil
        }
        for segment in message.segments.suffix(from: 1) {
            if let text = segment.text {
                parts.append(text.trim())
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
