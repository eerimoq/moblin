import Foundation
@testable import Moblin
import Testing

private func decodeStream(_ json: String) throws -> SettingsStream {
    try JSONDecoder().decode(SettingsStream.self, from: Data(json.utf8))
}

private func removeFromKeychain(_ id: UUID) {
    removeTwitchAccessTokenInKeychain(streamId: id)
    removeKickAccessTokenInKeychain(streamId: id)
    removeYouTubeAuthStateInKeychain(streamId: id)
}

struct SettingsStreamSuite {
    @Test(arguments: [
        (#"{}"#, "original"),
        (#"{"chzzkChannelId":""}"#, ""),
        (#"{"chzzkChannelId":"invalid"}"#, "original"),
        (#"{"chzzkChannelId":" 0123456789abcdef0123456789abcdef "}"#, "0123456789abcdef0123456789abcdef"),
    ])
    func remoteChannelUpdatePreservesOmittedId(json: String, expected: String) throws {
        let incoming = try decodeStream(json)
        let current = SettingsStream(name: "Main")
        current.chzzkChannelId = "original"
        let changed = current.updateChzzkChannelId(from: incoming)
        #expect(current.chzzkChannelId == expected)
        #expect(changed == (expected != "original"))
    }

    @Test
    func legacyDonationPreferenceBecomesIndependentVideoPreference() throws {
        let stream = try decodeStream(#"{"chzzkChatDonations":false}"#)
        #expect(!stream.chzzkChatVideoDonations)
        stream.chzzkChatDonations = true
        #expect(!stream.chzzkChatVideoDonations)
        #expect(stream.chzzkChatSubscriptions)
    }

    @Test
    func blankChannelUsesSignedInChannel() {
        let stream = SettingsStream(name: "Main")
        let channelId = "0123456789abcdef0123456789abcdef"
        #expect(stream.setChzzkChannelId("", signedInChannelId: channelId))
        #expect(stream.chzzkChannelId == channelId)
    }

    @Test(arguments: [
        (#"{}"#, false, true),
        (#"{"chzzkChatDonations":true}"#, true, true),
        (#"{"chzzkToastDonations":false}"#, false, false),
    ])
    func remoteDonationAlerts(json: String, chat: Bool, toast: Bool) throws {
        let incoming = try decodeStream(json)
        let current = SettingsStream(name: "Main")
        current.chzzkChatDonations = false
        current.chzzkToastDonations = true
        current.updateChzzkDonationAlerts(from: incoming)
        #expect(current.chzzkChatDonations == chat)
        #expect(current.chzzkToastDonations == toast)
    }

    @Test
    func decodingDoesNotTouchTheKeychain() throws {
        let id = UUID()
        defer {
            removeFromKeychain(id)
        }
        let stream = try decodeStream(#"{"id":"\#(id.uuidString)","kickAccessToken":"kick"}"#)
        #expect(stream.kickAccessToken == "kick")
        #expect(loadKickAccessTokenFromKeychain(streamId: id) == nil)
    }

    @Test
    func loadingIgnoresPlainTextTokens() throws {
        let id = UUID()
        defer {
            removeFromKeychain(id)
        }
        let stream = try decodeStream(
            #"{"id":"\#(id.uuidString)","twitchAccessToken":"twitch","kickAccessToken":"kick"}"#
        )
        stream.loadFromKeychain()
        #expect(stream.twitchAccessToken == "" && stream.kickAccessToken == "")
        #expect(loadKickAccessTokenFromKeychain(streamId: id) == nil)
    }

    @Test
    func loadingTakesTheTokensFromTheKeychain() throws {
        let id = UUID()
        defer {
            removeFromKeychain(id)
        }
        storeTwitchAccessTokenInKeychain(streamId: id, accessToken: "twitch")
        storeKickAccessTokenInKeychain(streamId: id, accessToken: "kick")
        let stream = try decodeStream(#"{"id":"\#(id.uuidString)"}"#)
        #expect(stream.twitchAccessToken == "" && stream.kickAccessToken == "")
        stream.loadFromKeychain()
        #expect(stream.twitchAccessToken == "twitch" && stream.kickAccessToken == "kick")
    }
}
