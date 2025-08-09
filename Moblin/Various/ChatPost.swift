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
    let titleSegments: [ChatPostSegment]
    var title: String {
        titleSegments.compactMap { segment in
            segment.text ?? (segment.url != nil ? "[emote]" : nil)
        }.joined()
    }

    var titleForWatchDisplay: String {
        titleSegments.compactMap { segment in
            segment.text
        }.joined()
    }

    static func makeReply(user: String, segments: [ChatPostSegment]) -> ChatHighlight {
        let prefixText = String(localized: "Replying to \(user): ")
        var replySegments: [ChatPostSegment] = []
        var id = 0
        // Add prefix text segment
        replySegments.append(ChatPostSegment(id: id, text: prefixText))
        id += 1
        // Add original message segments (limited for preview)
        var totalLength = prefixText.count
        for segment in segments {
            let textLength = segment.text?.count ?? 0
            let emoteLength = segment.url != nil ? 3 : 0
            let segmentLength = textLength + emoteLength

            if totalLength + segmentLength > 65 {
                let remainingLength = 65 - totalLength
                if remainingLength > 3 {
                    if let text = segment.text {
                        let truncatedText = String(text.prefix(remainingLength - 3)) + "..."
                        replySegments.append(ChatPostSegment(id: id, text: truncatedText))
                    } else {
                        replySegments.append(ChatPostSegment(id: id, text: "..."))
                    }
                } else {
                    replySegments.append(ChatPostSegment(id: id, text: "..."))
                }
                id += 1
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
        let announcementText = String(localized: "Announcement")
        return ChatHighlight(
            kind: .other,
            barColor: .green,
            image: "horn.blast",
            titleSegments: [ChatPostSegment(id: 0, text: announcementText)]
        )
    }

    static func makeFirstMessage() -> ChatHighlight {
        let firstMessageText = String(localized: "First time chatter")
        return ChatHighlight(
            kind: .firstMessage,
            barColor: .yellow,
            image: "bubble.left",
            titleSegments: [ChatPostSegment(id: 0, text: firstMessageText)]
        )
    }

    static func makePaidMessage(amount: String) -> ChatHighlight {
        let paidMessageText = String(localized: "Super Chat\(amount)")
        return ChatHighlight(
            kind: .other,
            barColor: .orange,
            image: "message",
            titleSegments: [ChatPostSegment(id: 0, text: paidMessageText)]
        )
    }

    static func makePaidSticker(amount: String) -> ChatHighlight {
        let paidStickerText = String(localized: "Super Sticker\(amount)")
        return ChatHighlight(
            kind: .other,
            barColor: .green,
            image: "doc.plaintext",
            titleSegments: [ChatPostSegment(id: 0, text: paidStickerText)]
        )
    }

    static func makeMember() -> ChatHighlight {
        let memberText = String(localized: "Member")
        return ChatHighlight(kind: .other,
                             barColor: .blue,
                             image: "medal",
                             titleSegments: [ChatPostSegment(id: 0, text: memberText)])
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
            title: titleForWatchDisplay
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
