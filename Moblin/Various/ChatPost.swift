import SwiftUI

struct ChatMessageEmote: Identifiable {
    let id = UUID()
    let url: URL
    let range: ClosedRange<Int>
}

struct ChatPostSegment: Identifiable, Codable {
    let id: Int
    var text: String?
    var url: URL?
}

func makeChatPostTextSegments(text: String, id: inout Int) -> [ChatPostSegment] {
    var segments: [ChatPostSegment] = []
    for word in text.split(separator: " ") {
        segments.append(ChatPostSegment(
            id: id,
            text: "\(word) "
        ))
        id += 1
    }
    return segments
}

enum ChatHighlightKind: Codable {
    case redemption
    case other
    case firstMessage
    case newFollower
    case reply
}

struct ChatHighlight {
    let kind: ChatHighlightKind
    let barColor: Color
    let image: String
    let title: String

    static func makeReply(user: String, segments: [ChatPostSegment]) -> ChatHighlight {
        var title = String(localized: "Replying to \(user):")
        for segment in segments {
            if let text = segment.text {
                title += " \(text.trim())"
            }
            if title.count > 65 {
                title += "..."
                break
            }
        }
        return ChatHighlight(kind: .reply,
                             barColor: .purple,
                             image: "arrowshape.turn.up.left",
                             title: title)
    }

    static func makeAnnouncement() -> ChatHighlight {
        return ChatHighlight(
            kind: .other,
            barColor: .green,
            image: "horn.blast",
            title: String(localized: "Announcement")
        )
    }

    static func makeFirstMessage() -> ChatHighlight {
        return ChatHighlight(
            kind: .firstMessage,
            barColor: .yellow,
            image: "bubble.left",
            title: String(localized: "First time chatter")
        )
    }

    static func makePaidMessage(amount: String) -> ChatHighlight {
        return ChatHighlight(
            kind: .other,
            barColor: .orange,
            image: "message",
            title: String(localized: "Super Chat\(amount)")
        )
    }

    static func makePaidSticker(amount: String) -> ChatHighlight {
        return ChatHighlight(
            kind: .other,
            barColor: .green,
            image: "doc.plaintext",
            title: String(localized: "Super Sticker\(amount)")
        )
    }

    static func makeMember() -> ChatHighlight {
        return ChatHighlight(kind: .other,
                             barColor: .blue,
                             image: "medal",
                             title: String(localized: "Member"))
    }

    func toWatchProtocol() -> WatchProtocolChatHighlight {
        let watchProtocolKind: WatchProtocolChatHighlightKind
        switch kind {
        case .redemption:
            watchProtocolKind = .redemption
        case .other:
            watchProtocolKind = .other
        case .newFollower:
            watchProtocolKind = .redemption
        case .firstMessage:
            watchProtocolKind = .other
        case .reply:
            watchProtocolKind = .reply
        }
        let barColor = barColor.toRgb() ?? .init(red: 0, green: 255, blue: 0)
        return WatchProtocolChatHighlight(
            kind: watchProtocolKind,
            barColor: .init(red: barColor.red, green: barColor.green, blue: barColor.blue),
            image: image,
            title: title
        )
    }

    func messageColor(defaultColor: Color = .white) -> Color {
        if kind == .reply {
            return .gray
        } else {
            return defaultColor
        }
    }
}

class ChatPostState: ObservableObject {
    @Published var deleted: Bool

    init() {
        deleted = false
    }
}

struct ChatPost: Identifiable, Equatable {
    static func == (lhs: ChatPost, rhs: ChatPost) -> Bool {
        return lhs.id == rhs.id
    }

    func isRedemption() -> Bool {
        return highlight?.kind == .redemption || highlight?.kind == .newFollower
    }

    var id: Int
    let messageId: String?
    let user: String?
    var userId: String?
    let userColor: RgbColor
    let userBadges: [URL]
    let segments: [ChatPostSegment]
    let timestamp: String
    let timestampTime: ContinuousClock.Instant
    let isAction: Bool
    let isSubscriber: Bool
    let bits: String?
    let highlight: ChatHighlight?
    let live: Bool
    let filter: SettingsChatFilter?
    let platform: Platform?
    let state: ChatPostState

    func text() -> String {
        return segments.filter { $0.text != nil }.map { $0.text! }.joined(separator: "").trim()
    }

    func isRedLine() -> Bool {
        return user == nil
    }
}
