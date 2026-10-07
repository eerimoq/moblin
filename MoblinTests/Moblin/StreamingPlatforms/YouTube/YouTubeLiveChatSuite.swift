import Foundation
@testable import Moblin
import Testing

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

struct YouTubeLiveChatSuite {
    private func parse(_ data: Data, emotes: [String] = []) throws -> YouTubeGetLiveChatResponse {
        try parseYouTubeGetLiveChat(data: data, emotes: makeEmotes(emotes))
    }

    @Test
    func textMessage() throws {
        let response = try parse(makeGetLiveChat(actions: [
            makeTextMessage(runs: #"[{"text": "hello world"}]"#),
        ]))
        #expect(response.continuation == "next")
        #expect(response.messages.count == 1)
        let message = response.messages[0]
        #expect(message.user == "Viewer")
        #expect(message.userId == "UC123")
        #expect(texts(message.segments) == ["hello ", "world "])
        #expect(!message.isOwner)
        #expect(!message.isModerator)
        #expect(message.highlight == nil)
    }

    @Test
    func emoji() throws {
        let response = try parse(makeGetLiveChat(actions: [
            makeTextMessage(runs: #"[{"text": "hi "}, \#(emojiRun), {"text": " there"}]"#),
        ]))
        let segments = response.messages[0].segments
        #expect(texts(segments) == ["hi ", nil, "there "])
        #expect(segments[1].url?.still?.absoluteString == "https://yt3.example.com/yt.png")
        #expect(Set(segments.map(\.id)).count == segments.count)
        #expect(spokenEmoteNames(segments) == [nil, "yt", nil])
    }

    @Test
    func emojiWithoutShortcutsHasNoName() throws {
        let emoji = #"{"emoji": {"image": {"thumbnails": [{"url": "https://yt3.example.com/a.png"}]}}}"#
        let response = try parse(makeGetLiveChat(actions: [makeTextMessage(runs: "[\(emoji)]")]))
        #expect(response.messages[0].segments[0].url != nil)
        #expect(spokenEmoteNames(response.messages[0].segments) == [nil])
    }

    @Test
    func emojiWithoutThumbnailIsSkipped() throws {
        let response = try parse(makeGetLiveChat(actions: [
            makeTextMessage(runs: #"[{"text": "hi"}, {"emoji": {"image": {"thumbnails": []}}}]"#),
        ]))
        #expect(texts(response.messages[0].segments) == ["hi "])
    }

    @Test
    func thirdPartyEmotes() throws {
        let response = try parse(makeGetLiveChat(actions: [
            makeTextMessage(runs: #"[{"text": "hi LUL"}]"#),
        ]), emotes: ["LUL"])
        let segments = response.messages[0].segments
        #expect(texts(segments) == ["hi ", "", ""])
        #expect(emoteNames(segments) == [nil, "LUL", nil])
    }

    @Test
    func ownerAndModeratorBadges() throws {
        let response = try parse(makeGetLiveChat(actions: [
            makeTextMessage(runs: #"[{"text": "a"}]"#, badges: "[\(makeBadge("OWNER"))]"),
            makeTextMessage(runs: #"[{"text": "b"}]"#, badges: "[\(makeBadge("MODERATOR"))]"),
            makeTextMessage(runs: #"[{"text": "c"}]"#, badges: "[\(makeBadge("VERIFIED")), {}]"),
        ]))
        #expect(response.messages.map(\.isOwner) == [true, false, false])
        #expect(response.messages.map(\.isModerator) == [false, true, false])
    }

    @Test
    func emptyTextMessageIsDropped() throws {
        let response = try parse(makeGetLiveChat(actions: [
            makeTextMessage(runs: "[]"),
            makeTextMessage(runs: #"[{"text": "kept"}]"#),
        ]))
        #expect(response.messages.map { texts($0.segments) } == [["kept "]])
    }

    @Test
    func paidMessage() throws {
        let response = try parse(makeGetLiveChat(actions: [makeAction(#"""
        "liveChatPaidMessageRenderer": {
            "authorName": {"simpleText": "Fan"},
            "purchaseAmountText": {"simpleText": "$5.00"},
            "message": {"runs": [{"text": "great stream"}]}
        }
        """#)]))
        let message = response.messages[0]
        #expect(message.user == "Fan")
        #expect(message.userId == nil)
        #expect(message.highlight?.image == "message")
        let text = message.segments.compactMap(\.text).joined()
        #expect(text.contains("$5.00"))
        #expect(text.hasSuffix("great stream "))
    }

    @Test
    func paidStickerWithoutMessage() throws {
        let response = try parse(makeGetLiveChat(actions: [makeAction(#"""
        "liveChatPaidStickerRenderer": {
            "authorName": {"simpleText": "Fan"},
            "purchaseAmountText": {"simpleText": "€2.00"}
        }
        """#)]))
        let message = response.messages[0]
        #expect(message.highlight?.image == "doc.plaintext")
        #expect(message.segments.compactMap(\.text).joined().contains("€2.00"))
    }

    @Test
    func membershipWithoutTextIsKept() throws {
        let response = try parse(makeGetLiveChat(actions: [makeAction(#"""
        "liveChatMembershipItemRenderer": {
            "authorName": {"simpleText": "Member"}
        }
        """#)]))
        #expect(response.messages.count == 1)
        #expect(response.messages[0].segments.isEmpty)
        #expect(response.messages[0].highlight?.image == "medal")
    }

    @Test
    func membershipHeaderSubtextComesBeforeMessage() throws {
        let response = try parse(makeGetLiveChat(actions: [makeAction(#"""
        "liveChatMembershipItemRenderer": {
            "authorName": {"simpleText": "Member"},
            "headerSubtext": {"runs": [{"text": "Welcome"}]},
            "message": {"runs": [{"text": "hi"}]}
        }
        """#)]))
        #expect(texts(response.messages[0].segments) == ["Welcome ", "hi "])
    }

    @Test
    func giftPurchase() throws {
        let response = try parse(makeGetLiveChat(actions: [makeAction(#"""
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
        let message = response.messages[0]
        #expect(message.user == "Gifter")
        #expect(message.userId == "UC456")
        #expect(message.isModerator)
        #expect(message.highlight?.image == "gift")
        #expect(texts(message.segments) == ["Gifted ", "5 ", "memberships "])
    }

    @Test
    func giftPurchaseWithoutTextIsDropped() throws {
        let response = try parse(makeGetLiveChat(actions: [makeAction(#"""
        "liveChatSponsorshipsGiftPurchaseAnnouncementRenderer": {
            "header": {
                "liveChatSponsorshipsHeaderRenderer": {
                    "authorName": {"simpleText": "Gifter"}
                }
            }
        }
        """#)]))
        #expect(response.messages.isEmpty)
    }

    @Test
    func giftRedemption() throws {
        let response = try parse(makeGetLiveChat(actions: [makeAction(#"""
        "liveChatSponsorshipsGiftRedemptionAnnouncementRenderer": {
            "authorName": {"simpleText": "Lucky"},
            "message": {"runs": [{"text": "received a gift membership"}]}
        }
        """#)]))
        #expect(response.messages[0].user == "Lucky")
        #expect(response.messages[0].highlight?.image == "gift")
    }

    @Test
    func giftMessageViewModel() throws {
        let response = try parse(makeGetLiveChat(actions: [makeAction(#"""
        "giftMessageViewModel": {
            "authorName": {"content": "Jeweler"},
            "text": {"content": "sent Girl power for 50 Jewels"}
        }
        """#)]))
        let message = response.messages[0]
        #expect(message.user == "Jeweler")
        #expect(message.userId == nil)
        #expect(message.highlight?.image == "diamond")
        #expect(message.segments.compactMap(\.text).joined() == "sent Girl power for 50 Jewels ")
    }

    @Test
    func unknownActionsAreIgnored() throws {
        let response = try parse(makeGetLiveChat(actions: [
            #"{"markChatItemAsDeletedAction": {"targetItemId": "abc"}}"#,
            makeAction(#""liveChatViewerEngagementMessageRenderer": {"id": "x"}"#),
            makeTextMessage(runs: #"[{"text": "hi"}]"#),
        ]))
        #expect(response.messages.count == 1)
    }

    @Test
    func noActions() throws {
        let data = #"""
        {
            "continuationContents": {
                "liveChatContinuation": {
                    "continuations": [{"invalidationContinuationData": {"continuation": "abc"}}]
                }
            }
        }
        """#.utf8Data
        let response = try parse(data)
        #expect(response.messages.isEmpty)
        #expect(response.continuation == "abc")
    }

    @Test
    func missingContinuation() throws {
        let response = try parse(makeGetLiveChat(actions: [], continuation: nil))
        #expect(response.continuation == nil)
    }

    @Test
    func invalidJsonThrows() {
        #expect(throws: (any Error).self) {
            try parse("{}".utf8Data)
        }
    }

    @Test
    func initialContinuation() {
        let body = #"<script>var ytInitialData = {"continuation":"0ofMyAN","other":"x"};</script>"#
        #expect(parseYouTubeInitialContinuation(body: body) == "0ofMyAN")
        #expect(parseYouTubeInitialContinuation(body: "<html></html>") == nil)
    }

    @Test
    func videoId() {
        #expect(parseYouTubeVideoId(
            html: #"<link rel="shortlinkUrl" href="https://youtu.be/abc123">"#
        ) == "abc123")
        #expect(parseYouTubeVideoId(
            html: "<link rel='shortlinkUrl' href='https://youtu.be/def456'>"
        ) == "def456")
        #expect(parseYouTubeVideoId(
            html: #"<link itemprop="x" rel="shortlinkUrl" data-a="b" href="https://youtu.be/ghi789">"#
        ) == "ghi789")
        #expect(parseYouTubeVideoId(html: "<html></html>") == nil)
    }

    @Test
    func pollDelay() {
        #expect(youTubePollDelayMs(delay: 2000, numberOfMessages: 0) == 3000)
        #expect(youTubePollDelayMs(delay: 2000, numberOfMessages: 1) == 3000)
        #expect(youTubePollDelayMs(delay: 2000, numberOfMessages: 10) == 1000)
        #expect(youTubePollDelayMs(delay: 1000, numberOfMessages: 100) == 200)
    }
}
