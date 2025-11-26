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

func makeChatPostTextSegments(text: String) -> [ChatPostSegment] {
    var id = 0
    return makeChatPostTextSegments(text: text, id: &id)
}

func makeChatPostTextSegments(text: String, id: inout Int) -> [ChatPostSegment] {
    var segments: [ChatPostSegment] = []
    for word in text.components(separatedBy: .whitespacesAndNewlines) where !word.isEmpty {
        segments.append(ChatPostSegment(id: id, text: "\(word) "))
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
    let titleSegments: [ChatPostSegment]

    static func makeReply(user: String, segments: [ChatPostSegment]) -> ChatHighlight {
        let prefixText = String(localized: "Replying to \(user):")
        var id = 0
        var replySegments = makeChatPostTextSegments(text: prefixText, id: &id)
        var totalLength = prefixText.count
        for segment in segments {
            let textLength = segment.text?.count ?? 0
            let emoteLength = segment.url != nil ? 3 : 0
            let segmentLength = textLength + emoteLength
            if totalLength + segmentLength > 65 {
                let remainingLength = 65 - totalLength
                let truncatedText: String
                if remainingLength > 3, let text = segment.text {
                    truncatedText = String(text.prefix(remainingLength - 3)) + "..."
                } else {
                    truncatedText = "..."
                }
                replySegments.append(ChatPostSegment(id: id, text: truncatedText))
                break
            }
            totalLength += segmentLength
            replySegments.append(ChatPostSegment(id: id, text: segment.text, url: segment.url))
            id += 1
        }
        return ChatHighlight(kind: .reply,
                             barColor: .purple,
                             image: "arrowshape.turn.up.left",
                             titleSegments: replySegments)
    }

    static func makeAnnouncement() -> ChatHighlight {
        return ChatHighlight(
            kind: .other,
            barColor: .green,
            image: "horn.blast",
            titleSegments: makeChatPostTextSegments(text: String(localized: "Announcement"))
        )
    }

    static func makeFirstMessage() -> ChatHighlight {
        return ChatHighlight(
            kind: .firstMessage,
            barColor: .yellow,
            image: "bubble.left",
            titleSegments: makeChatPostTextSegments(text: String(localized: "First time chatter"))
        )
    }

    static func makePaidMessage(amount: String) -> ChatHighlight {
        return ChatHighlight(
            kind: .other,
            barColor: .orange,
            image: "message",
            titleSegments: makeChatPostTextSegments(text: String(localized: "Super Chat\(amount)"))
        )
    }

    static func makePaidSticker(amount: String) -> ChatHighlight {
        return ChatHighlight(
            kind: .other,
            barColor: .green,
            image: "doc.plaintext",
            titleSegments: makeChatPostTextSegments(text: String(localized: "Super Sticker\(amount)"))
        )
    }

    static func makeMember() -> ChatHighlight {
        return ChatHighlight(kind: .other,
                             barColor: .blue,
                             image: "medal",
                             titleSegments: makeChatPostTextSegments(text: String(localized: "Member")))
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
            title: titleNoEmotes()
        )
    }

    func titleNoEmotes() -> String {
        return titleSegments.compactMap { $0.text }.joined()
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
    let displayName: String?
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

    func displayName(nicknames: SettingsChatNicknames, displayStyle: SettingsChatDisplayStyle) -> String {
        guard let displayName, let user else {
            return String(localized: "Unknown")
        }
        if let nickname = nicknames.getNickname(user: user) {
            return "\(nickname) @\(user)"
        }
        switch displayStyle {
        case .internationalNameAndUsername:
            if displayName.compare(user, options: .caseInsensitive) == .orderedSame {
                return displayName
            } else {
                return "\(displayName) (\(user))"
            }
        case .internationalName:
            return displayName
        case .username:
            return user
        }
    }

    func shortDisplayName(nicknames: SettingsChatNicknames) -> String {
        guard let displayName, let user else {
            return String(localized: "Unknown")
        }
        if let nickname = nicknames.getNickname(user: user) {
            return nickname
        }
        return displayName
    }
}
