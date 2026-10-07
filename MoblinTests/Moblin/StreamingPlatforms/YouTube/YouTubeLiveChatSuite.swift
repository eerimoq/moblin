import Foundation
@testable import Moblin
import Testing

private struct Message {
    let user: String
    let userId: String?
    let segments: [ChatPostSegment]
    let isModerator: Bool
    let isOwner: Bool
    let highlight: ChatHighlight?
}

@MainActor
private final class Delegate: YouTubeLiveChatDelegate {
    var messages: [Message] = []

    func youTubeLiveChatMakeErrorToast(title _: String, subTitle _: String) {}

    func youTubeLiveChatMakeToast(title _: String) {}

    func youTubeLiveChatAppendMessage(user: String,
                                      userId: String?,
                                      segments: [ChatPostSegment],
                                      isModerator: Bool,
                                      isOwner: Bool,
                                      highlight: ChatHighlight?)
    {
        messages.append(Message(user: user,
                                userId: userId,
                                segments: segments,
                                isModerator: isModerator,
                                isOwner: isOwner,
                                highlight: highlight))
    }
}

private func makeGetLiveChat(actions: [String], continuation: String? = "next") -> Data {
    let continuations = if let continuation {
        #"[{"invalidationContinuationData": {"continuation": "\#(continuation)"}}]"#
    } else {
        "[]"
    }
    return """
    {
        "continuationContents": {
            "liveChatContinuation": {
                "continuations": \(continuations),
                "actions": [\(actions.joined(separator: ","))]
            }
        }
    }
    """.utf8Data
}

private func makeAction(_ item: String) -> String {
    #"{"addChatItemAction": {"item": {\#(item)}}}"#
}

private func makeTextMessage(author: String = "Viewer",
                             runs: String,
                             badges: String = "[]") -> String
{
    makeAction(#"""
    "liveChatTextMessageRenderer": {
        "authorName": {"simpleText": "\#(author)"},
        "authorExternalChannelId": "UC123",
        "message": {"runs": \#(runs)},
        "authorBadges": \#(badges)
    }
    """#)
}

private func makeBadge(_ iconType: String) -> String {
    #"{"liveChatAuthorBadgeRenderer": {"icon": {"iconType": "\#(iconType)"}}}"#
}

private let emojiRun = #"""
{
    "emoji": {
        "emojiId": "UCkszU2WH9gy1mb0dV-11UJg/1",
        "shortcuts": [":yt:", ":youtube:"],
        "image": {"thumbnails": [{"url": "https://yt3.example.com/yt.png"}]}
    }
}
"""#

@MainActor
struct YouTubeLiveChatSuite {
    private func handle(_ data: Data) throws -> [Message] {
        let delegate = Delegate()
        let chat = YouTubeLiveChat(delegate: delegate, videoId: "video", settings: SettingsStreamChat())
        try chat.handleGetLiveChat(data: data)
        return delegate.messages
    }

    @Test
    func textMessage() throws {
        let messages = try handle(makeGetLiveChat(actions: [
            makeTextMessage(runs: #"[{"text": "hello world"}]"#),
        ]))
        #expect(messages.count == 1)
        let message = messages[0]
        #expect(message.user == "Viewer")
        #expect(message.userId == "UC123")
        #expect(texts(message.segments) == ["hello ", "world "])
        #expect(!message.isOwner)
        #expect(!message.isModerator)
        #expect(message.highlight == nil)
    }

    @Test
    func emoji() throws {
        let messages = try handle(makeGetLiveChat(actions: [
            makeTextMessage(runs: #"[{"text": "hi "}, \#(emojiRun), {"text": " there"}]"#),
        ]))
        let segments = messages[0].segments
        #expect(texts(segments) == ["hi ", nil, "there "])
        #expect(segments[1].url?.still?.absoluteString == "https://yt3.example.com/yt.png")
        #expect(Set(segments.map(\.id)).count == segments.count)
    }

    @Test
    func emojiWithoutThumbnailIsSkipped() throws {
        let messages = try handle(makeGetLiveChat(actions: [
            makeTextMessage(runs: #"[{"text": "hi"}, {"emoji": {"image": {"thumbnails": []}}}]"#),
        ]))
        #expect(texts(messages[0].segments) == ["hi "])
    }

    @Test
    func ownerAndModeratorBadges() throws {
        let messages = try handle(makeGetLiveChat(actions: [
            makeTextMessage(runs: #"[{"text": "a"}]"#, badges: "[\(makeBadge("OWNER"))]"),
            makeTextMessage(runs: #"[{"text": "b"}]"#, badges: "[\(makeBadge("MODERATOR"))]"),
            makeTextMessage(runs: #"[{"text": "c"}]"#, badges: "[\(makeBadge("VERIFIED")), {}]"),
        ]))
        #expect(messages.map(\.isOwner) == [true, false, false])
        #expect(messages.map(\.isModerator) == [false, true, false])
    }

    @Test
    func emptyTextMessageIsDropped() throws {
        let messages = try handle(makeGetLiveChat(actions: [
            makeTextMessage(runs: "[]"),
            makeTextMessage(runs: #"[{"text": "kept"}]"#),
        ]))
        #expect(messages.map { texts($0.segments) } == [["kept "]])
    }

    @Test
    func paidMessage() throws {
        let messages = try handle(makeGetLiveChat(actions: [makeAction(#"""
        "liveChatPaidMessageRenderer": {
            "authorName": {"simpleText": "Fan"},
            "purchaseAmountText": {"simpleText": "$5.00"},
            "message": {"runs": [{"text": "great stream"}]}
        }
        """#)]))
        let message = messages[0]
        #expect(message.user == "Fan")
        #expect(message.userId == nil)
        #expect(message.highlight?.image == "message")
        let text = message.segments.compactMap(\.text).joined()
        #expect(text.contains("$5.00"))
        #expect(text.hasSuffix("great stream "))
    }

    @Test
    func paidStickerWithoutMessage() throws {
        let messages = try handle(makeGetLiveChat(actions: [makeAction(#"""
        "liveChatPaidStickerRenderer": {
            "authorName": {"simpleText": "Fan"},
            "purchaseAmountText": {"simpleText": "€2.00"}
        }
        """#)]))
        let message = messages[0]
        #expect(message.highlight?.image == "doc.plaintext")
        #expect(message.segments.compactMap(\.text).joined().contains("€2.00"))
    }

    @Test
    func membershipWithoutTextIsKept() throws {
        let messages = try handle(makeGetLiveChat(actions: [makeAction(#"""
        "liveChatMembershipItemRenderer": {
            "authorName": {"simpleText": "Member"}
        }
        """#)]))
        #expect(messages.count == 1)
        #expect(messages[0].segments.isEmpty)
        #expect(messages[0].highlight?.image == "medal")
    }

    @Test
    func membershipHeaderSubtextComesBeforeMessage() throws {
        let messages = try handle(makeGetLiveChat(actions: [makeAction(#"""
        "liveChatMembershipItemRenderer": {
            "authorName": {"simpleText": "Member"},
            "headerSubtext": {"runs": [{"text": "Welcome"}]},
            "message": {"runs": [{"text": "hi"}]}
        }
        """#)]))
        #expect(texts(messages[0].segments) == ["Welcome ", "hi "])
    }

    @Test
    func giftPurchase() throws {
        let messages = try handle(makeGetLiveChat(actions: [makeAction(#"""
        "liveChatSponsorshipsGiftPurchaseAnnouncementRenderer": {
            "header": {
                "liveChatSponsorshipsHeaderRenderer": {
                    "authorName": {"simpleText": "Gifter"},
                    "authorExternalChannelId": "UC456",
                    "primaryText": {"runs": [{"text": "Gifted "}, {"text": "5"}, {"text": " memberships"}]},
                    "authorBadges": [\#(makeBadge("MODERATOR"))]
                }
            }
        }
        """#)]))
        let message = messages[0]
        #expect(message.user == "Gifter")
        #expect(message.userId == "UC456")
        #expect(message.isModerator)
        #expect(message.highlight?.image == "gift")
        #expect(texts(message.segments) == ["Gifted ", "5 ", "memberships "])
    }

    @Test
    func giftPurchaseWithoutTextIsDropped() throws {
        let messages = try handle(makeGetLiveChat(actions: [makeAction(#"""
        "liveChatSponsorshipsGiftPurchaseAnnouncementRenderer": {
            "header": {
                "liveChatSponsorshipsHeaderRenderer": {
                    "authorName": {"simpleText": "Gifter"}
                }
            }
        }
        """#)]))
        #expect(messages.isEmpty)
    }

    @Test
    func giftRedemption() throws {
        let messages = try handle(makeGetLiveChat(actions: [makeAction(#"""
        "liveChatSponsorshipsGiftRedemptionAnnouncementRenderer": {
            "authorName": {"simpleText": "Lucky"},
            "message": {"runs": [{"text": "received a gift membership"}]}
        }
        """#)]))
        #expect(messages[0].user == "Lucky")
        #expect(messages[0].highlight?.image == "gift")
    }

    @Test
    func giftMessageViewModel() throws {
        let messages = try handle(makeGetLiveChat(actions: [makeAction(#"""
        "giftMessageViewModel": {
            "authorName": {"content": "Jeweler"},
            "text": {"content": "sent Girl power for 50 Jewels"}
        }
        """#)]))
        let message = messages[0]
        #expect(message.user == "Jeweler")
        #expect(message.userId == nil)
        #expect(message.highlight?.image == "diamond")
        #expect(message.segments.compactMap(\.text).joined() == "sent Girl power for 50 Jewels ")
    }

    @Test
    func unknownActionsAreIgnored() throws {
        let messages = try handle(makeGetLiveChat(actions: [
            #"{"markChatItemAsDeletedAction": {"targetItemId": "abc"}}"#,
            makeAction(#""liveChatViewerEngagementMessageRenderer": {"id": "x"}"#),
            makeTextMessage(runs: #"[{"text": "hi"}]"#),
        ]))
        #expect(messages.count == 1)
    }

    @Test
    func noActions() throws {
        let messages = try handle(#"""
        {
            "continuationContents": {
                "liveChatContinuation": {
                    "continuations": [{"invalidationContinuationData": {"continuation": "abc"}}]
                }
            }
        }
        """#.utf8Data)
        #expect(messages.isEmpty)
    }

    @Test
    func missingContinuationThrows() {
        #expect(throws: (any Error).self) {
            try handle(makeGetLiveChat(actions: [], continuation: nil))
        }
    }

    @Test
    func invalidJsonThrows() {
        #expect(throws: (any Error).self) {
            try handle("{}".utf8Data)
        }
    }
}
