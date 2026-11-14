import Foundation
@testable import Moblin
import Testing

private func decodeStream(_ json: String) throws -> SettingsStream {
    try JSONDecoder().decode(SettingsStream.self, from: Data(json.utf8))
}

private func removeFromKeychain(_ id: UUID) {
    removeTwitchAccessTokenInKeychain(streamId: id)
    removeKickAccessTokenInKeychain(streamId: id)
    removeVkVideoLiveAccessTokenInKeychain(streamId: id)
    removeYouTubeAuthStateInKeychain(streamId: id)
}

struct SettingsStreamSuite {
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
    func loadingIgnoresPlainTextVkVideoLiveToken() throws {
        let id = UUID()
        defer {
            removeFromKeychain(id)
        }
        let stream = try decodeStream(#"{"id":"\#(id.uuidString)","vkVideoLiveAccessToken":"vk"}"#)
        stream.loadFromKeychain()
        #expect(stream.vkVideoLiveAccessToken == "")
        #expect(loadVkVideoLiveAccessTokenFromKeychain(streamId: id) == nil)
    }

    @Test
    func loadingTakesTheVkVideoLiveTokenFromTheKeychain() throws {
        let id = UUID()
        defer {
            removeFromKeychain(id)
        }
        storeVkVideoLiveAccessTokenInKeychain(streamId: id, accessToken: "vk")
        let stream = try decodeStream(#"{"id":"\#(id.uuidString)"}"#)
        #expect(stream.vkVideoLiveAccessToken == "")
        stream.loadFromKeychain()
        #expect(stream.vkVideoLiveAccessToken == "vk")
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
